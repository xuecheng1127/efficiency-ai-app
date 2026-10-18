import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/task_enums.dart';
import '../domain/task_instance.dart';
import '../domain/task_repository.dart';
import '../domain/task_template.dart';
import '../engine/backfill.dart' as backfill_engine;
import 'task_mapper.dart';

/// 任务仓库 Drift 实现（T01 规格 §10.3）
///
/// 实现 [TaskRepository]（Domain 接口）与 [BackfillStore]（Engine 抽象）：
/// - 所有常规读写使用 Drift 原生异步操作；
/// - 惰性补齐通过 Engine 层 [backfillOnAppStart] 调用（幂等，红线 1/2/3）；
/// - 常规查询一律过滤 `deletedAt IS NULL` 与 `archivedAt IS NULL`（规格 2.3-4）；
/// - 快照原则：插入实例时复制模板快照，改模板不影响已生成实例（红线 5）。
class TaskRepositoryImpl implements TaskRepository, backfill_engine.BackfillStore {
  final AppDatabase _db;

  TaskRepositoryImpl(this._db);

  // ==================== BackfillStore（Engine 数据访问） ====================

  @override
  Future<List<TaskTemplate>> loadActiveTemplates() async {
    final rows = await (_db.select(_db.taskTemplates)
          ..where((t) => t.archivedAt.isNull()))
        .get();
    return rows.map(TaskMapper.toTemplate).toList();
  }

  @override
  Future<DateTime?> lastGeneratedDate(int templateId) async {
    final maxDate = await (_db.selectOnly(_db.taskInstances)
          ..addColumns([_db.taskInstances.occurrenceDate.max()])
          ..where(_db.taskInstances.templateId.equals(templateId)))
        .getSingleOrNull();
    return maxDate?.read(_db.taskInstances.occurrenceDate.max());
  }

  @override
  Future<bool> upsertInstance(TaskTemplate template, DateTime date) async {
    // 评审方修复（2026-10-18）：插入侧必须与查询侧口径一致。
    //
    // 原 bug：getOccurrence 用 _normalizeDate(date) 比较（当天 0 点），
    // 但插入时直接把带时分秒的 date 存进 occurrenceDate。
    // 后果：模板 startDate 带时分秒（如 01:08:32）时，
    //   查询查 00:00:00 永远查不到 → 每次启动都重插同一行 →
    //   UNIQUE(templateId, occurrenceDate) 冲突 → 任务列表整页加载失败。
    // 单测没发现是因为测试用的都是 DateTime(y,m,d)（0 点整），归一化是空操作。
    final normalized = _normalizeDate(date);

    // 已存在（含软删除行）→ 原样返回，绝不覆盖（红线 2；D6 不复活）
    final existing = await getOccurrence(template.id!, normalized);
    if (existing != null) return false;

    await _db.into(_db.taskInstances).insert(
          TaskMapper.toInstanceCompanion(template, normalized),
        );
    return true;
  }

  // ==================== 任务模板 ====================

  @override
  Future<List<TaskTemplate>> getAllTasks() async {
    final rows = await (_db.select(_db.taskTemplates)
          ..where((t) => t.archivedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(TaskMapper.toTemplate).toList();
  }

  @override
  Stream<List<TaskTemplate>> watchAllTasks() {
    return (_db.select(_db.taskTemplates)
          ..where((t) => t.archivedAt.isNull()))
        .watch()
        .map((rows) => rows.map(TaskMapper.toTemplate).toList());
  }

  @override
  Future<int> addTask(TaskTemplate task) async {
    return _db.into(_db.taskTemplates).insert(
          TaskMapper.toTemplateCompanion(task),
        );
  }

  @override
  Future<void> updateTask(TaskTemplate task) async {
    if (task.id == null) {
      throw ArgumentError('updateTask 需要已入库的模板 id');
    }
    await (_db.update(_db.taskTemplates)..where((t) => t.id.equals(task.id!)))
        .write(TaskMapper.toTemplateUpdateCompanion(task));
  }

  @override
  Future<void> archiveTask(int templateId) async {
    await (_db.update(_db.taskTemplates)
          ..where((t) => t.id.equals(templateId)))
        .write(TaskTemplatesCompanion(
          archivedAt: Value(DateTime.now()),
        ));
  }

  @override
  Future<void> deleteTask(int templateId) async {
    await _db.transaction(() async {
      // 先删关联实例，再删模板
      await (_db.delete(_db.taskInstances)
            ..where((i) => i.templateId.equals(templateId)))
          .go();
      await (_db.delete(_db.taskTemplates)
            ..where((t) => t.id.equals(templateId)))
          .go();
    });
  }

  // ==================== 惰性补齐入口 ====================

  @override
  Future<void> backfillOnAppStart(DateTime today) {
    // 注意：engine 顶层函数与本类方法同名，用 import 前缀调用避免遮蔽
    return backfill_engine.backfillOnAppStart(this, _normalizeDate(today));
  }

  // ==================== 当日实例 / 今日任务 ====================

  @override
  Future<TaskInstance?> getOccurrence(int templateId, DateTime date) async {
    final row = await (_db.select(_db.taskInstances)
          ..where((i) =>
              i.templateId.equals(templateId) &
              i.occurrenceDate.equals(_normalizeDate(date))))
        .getSingleOrNull();
    return row == null ? null : TaskMapper.toInstance(row);
  }

  @override
  Future<TaskInstance?> getOccurrenceById(int occurrenceId) async {
    final row = await (_db.select(_db.taskInstances)
          ..where((i) => i.id.equals(occurrenceId)))
        .getSingleOrNull();
    return row == null ? null : TaskMapper.toInstance(row);
  }

  @override
  Future<List<TaskInstance>> getOccurrencesByDate(
      int templateId, DateTime date) async {
    final rows = await (_db.select(_db.taskInstances)
          ..where((i) =>
              i.templateId.equals(templateId) &
              i.occurrenceDate.equals(_normalizeDate(date))))
        .get();
    return rows.map(TaskMapper.toInstance).toList();
  }

  @override
  Future<List<TaskWithOccurrence>> getTodayTasks() async {
    final today = _normalizeDate(DateTime.now());
    // 先惰性补齐当日实例（幂等，每次启动/进主页都安全）
    await backfillOnAppStart(today);

    // 今日未删除实例（deletedAt IS NULL）
    final instances = await (_db.select(_db.taskInstances)
          ..where((i) =>
              i.occurrenceDate.equals(today) & i.deletedAt.isNull()))
        .get();

    final result = <TaskWithOccurrence>[];
    for (final instRow in instances) {
      final template = await getTemplateById(instRow.templateId);
      if (template == null) continue; // 模板不存在（理论不可达，防御）
      result.add(TaskWithOccurrence(
        task: template,
        occurrence: TaskMapper.toInstance(instRow),
      ));
    }
    // 按创建时间倒序（最近创建在前）
    result.sort((a, b) => b.task.createdAt.compareTo(a.task.createdAt));
    return result;
  }

  @override
  Stream<List<TaskWithOccurrence>> watchTodayTasks() {
    return Stream<List<TaskWithOccurrence>>.multi((controller) {
      Future<void> refresh() async {
        try {
          final list = await getTodayTasks();
          controller.add(list);
        } catch (e, st) {
          controller.addError(e, st);
        }
      }

      final subs = <StreamSubscription<dynamic>>[];
      // 模板变化（新增/修改/归档）
      subs.add((_db.select(_db.taskTemplates)..where((t) => t.archivedAt.isNull()))
          .watch()
          .listen((_) => refresh()));
      // 实例变化（三态流转/删除）
      subs.add(_db.select(_db.taskInstances).watch().listen((_) => refresh()));
      // 首次立即计算
      refresh();

      controller.onCancel = () {
        for (final s in subs) {
          s.cancel();
        }
      };
    });
  }

  /// 按模板 id 查模板（含归档，供今日列表 join；归档模板的历史实例仍展示）
  Future<TaskTemplate?> getTemplateById(int templateId) async {
    final row = await (_db.select(_db.taskTemplates)
          ..where((t) => t.id.equals(templateId)))
        .getSingleOrNull();
    return row == null ? null : TaskMapper.toTemplate(row);
  }

  // ==================== 三态流转（实例级） ====================

  @override
  Future<void> startTask(int occurrenceId) async {
    await _db.transaction(() async {
      final occ = await getOccurrenceById(occurrenceId);
      if (occ == null || occ.status == TaskStatus.done) return;
      await (_db.update(_db.taskInstances)..where((i) => i.id.equals(occurrenceId)))
          .write(TaskInstancesCompanion(
        status: Value(TaskStatus.inProgress.name),
        startedAt: Value(occ.startedAt ?? DateTime.now()),
      ));
    });
  }

  @override
  Future<void> completeTask(int occurrenceId, {int extraSeconds = 0}) async {
    await _db.transaction(() async {
      final occ = await getOccurrenceById(occurrenceId);
      if (occ == null) return;
      await (_db.update(_db.taskInstances)..where((i) => i.id.equals(occurrenceId)))
          .write(TaskInstancesCompanion(
        status: Value(TaskStatus.done.name),
        completedAt: Value(DateTime.now()),
        accumulatedSeconds: Value(occ.accumulatedSeconds + extraSeconds),
      ));
    });
  }

  @override
  Future<void> reopenTask(int occurrenceId) async {
    await _db.transaction(() async {
      final occ = await getOccurrenceById(occurrenceId);
      if (occ == null) return;
      await (_db.update(_db.taskInstances)..where((i) => i.id.equals(occurrenceId)))
          .write(TaskInstancesCompanion(
        status: Value(TaskStatus.todo.name),
        startedAt: const Value(null),
        completedAt: const Value(null),
      ));
    });
  }

  @override
  Future<void> pauseTask(int occurrenceId, {int elapsedSeconds = 0}) async {
    await _db.transaction(() async {
      final occ = await getOccurrenceById(occurrenceId);
      if (occ == null) return;
      await (_db.update(_db.taskInstances)..where((i) => i.id.equals(occurrenceId)))
          .write(TaskInstancesCompanion(
        status: Value(TaskStatus.todo.name),
        startedAt: const Value(null),
        accumulatedSeconds: Value(occ.accumulatedSeconds + elapsedSeconds),
      ));
    });
  }

  /// 归一化日期到当天 00:00:00
  static DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
