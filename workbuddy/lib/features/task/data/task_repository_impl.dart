import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/task_enums.dart';
import '../domain/task_instance.dart';
import '../domain/task_repository.dart';
import '../domain/task_template.dart';
import '../engine/backfill.dart' as engine;
import 'task_mapper.dart';

/// [TaskRepository] 的 Drift 实现。
class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<TaskInstance>> watchTodayInstances(DateTime today) {
    final d = engine.dateOnly(today);
    // join 模板：过滤「模板已归档」的实例（默认查询须过滤 archivedAt IS NULL）
    final query =
        _db.select(_db.taskInstances).join([
            innerJoin(
              _db.taskTemplates,
              _db.taskTemplates.id.equalsExp(_db.taskInstances.templateId),
            ),
          ])
          ..where(_db.taskInstances.occurrenceDate.equals(d))
          ..where(_db.taskInstances.deletedAt.isNull())
          ..where(_db.taskTemplates.archivedAt.isNull());

    return query.watch().map((rows) {
      final list = rows
          .map((r) => TaskMapper.toInstance(r.readTable(_db.taskInstances)))
          .toList();
      // 已完成沉底，其余按 id 升序
      list.sort((a, b) {
        final aDone = a.status == TaskStatus.done ? 1 : 0;
        final bDone = b.status == TaskStatus.done ? 1 : 0;
        if (aDone != bDone) return aDone - bDone;
        return a.id.compareTo(b.id);
      });
      return list;
    });
  }

  @override
  Future<int> addTemplate({
    required TaskType type,
    required String title,
    required RepeatMode repeatMode,
    List<int> repeatDays = const [],
  }) {
    return _db
        .into(_db.taskTemplates)
        .insert(
          TaskTemplatesCompanion.insert(
            type: type.name,
            title: title,
            repeatMode: repeatMode.name,
            repeatDays: Value(repeatDays.isEmpty ? null : repeatDays.join(',')),
            startDate: engine.dateOnly(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> backfill(DateTime today) {
    return engine.backfill(_BackfillDataSourceAdapter(_db), today);
  }

  @override
  Future<void> startTimer(int instanceId) {
    return (_db.update(
      _db.taskInstances,
    )..where((t) => t.id.equals(instanceId))).write(
      TaskInstancesCompanion(
        // NOTE: must be a literal, not TaskStatus.inProgress.name -- `.name` is an
        // extension getter and is not allowed in a const expression.
        status: const Value('inProgress'),
        startedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> completeInstance(int instanceId) async {
    // 事务内完成：读取 startedAt → 计算本次耗时 → 归档并切为已完成
    await _db.transaction(() async {
      final inst = await (_db.select(
        _db.taskInstances,
      )..where((t) => t.id.equals(instanceId))).getSingle();

      final now = DateTime.now();
      var addedSeconds = 0;
      if (inst.startedAt != null) {
        addedSeconds = now.difference(inst.startedAt!).inSeconds;
      }

      await (_db.update(
        _db.taskInstances,
      )..where((t) => t.id.equals(instanceId))).write(
        TaskInstancesCompanion(
          status: const Value('done'),
          completedAt: Value(now),
          startedAt: const Value<DateTime?>(null),
          accumulatedSeconds: Value(inst.accumulatedSeconds + addedSeconds),
        ),
      );
    });
  }

  @override
  Future<void> uncompleteInstance(int instanceId) {
    // WHERE 里带 status='done'：只有「已完成」能被撤回。
    // 正在计时的实例 status 是 inProgress，条件不成立 → 一行都不会被改，
    // 计时器不会被这次调用连坐（验收 §4）。
    return (_db.update(
      _db.taskInstances,
    )..where((t) => t.id.equals(instanceId) & t.status.equals('done'))).write(
      const TaskInstancesCompanion(
        status: Value('todo'),
        completedAt: Value<DateTime?>(null),
        startedAt: Value<DateTime?>(null),
        // 归档耗时一并清零，避免「取消完成后还挂着上次的耗时」
        accumulatedSeconds: Value(0),
      ),
    );
  }

  @override
  Future<void> cancelTimer(int instanceId) {
    return (_db.update(
      _db.taskInstances,
    )..where((t) => t.id.equals(instanceId))).write(
      TaskInstancesCompanion(
        status: const Value('todo'),
        startedAt: const Value<DateTime?>(null),
      ),
    );
  }

  @override
  Future<void> deleteInstance(int instanceId) {
    // 实例级软删除：不硬删，保留历史（规格 §2.3 约束 3）
    return (_db.update(_db.taskInstances)
          ..where((t) => t.id.equals(instanceId)))
        .write(TaskInstancesCompanion(deletedAt: Value(DateTime.now())));
  }

  @override
  Future<void> deleteTemplate(int templateId, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    await _db.transaction(() async {
      // 1) 归档模板 —— 「明天不再补回来」全靠这一列：
      //    backfill 只读 archivedAt IS NULL 的模板（见 _BackfillDataSourceAdapter），
      //    今日列表的 join 也过滤 archived，所以删完立刻从列表消失且不会再长出来。
      await (_db.update(_db.taskTemplates)
            ..where((t) => t.id.equals(templateId)))
          .write(TaskTemplatesCompanion(archivedAt: Value(at)));

      // 2) 该模板下的实例全部软删（含今日）；保留行以便历史统计/回溯
      await (_db.update(_db.taskInstances)..where(
            (t) => t.templateId.equals(templateId) & t.deletedAt.isNull(),
          ))
          .write(TaskInstancesCompanion(deletedAt: Value(at)));
    });
  }
}

/// 把 Drift 数据库适配为 backfill 算法的数据源抽象（依赖倒置的落地）。
class _BackfillDataSourceAdapter implements engine.BackfillDataSource {
  _BackfillDataSourceAdapter(this._db);

  final AppDatabase _db;

  @override
  Future<List<TaskTemplate>> getActiveTemplates() async {
    final rows = await (_db.select(
      _db.taskTemplates,
    )..where((t) => t.archivedAt.isNull())).get();
    return rows.map(TaskMapper.toTemplate).toList();
  }

  @override
  Future<DateTime?> lastOccurrenceDate(int templateId) async {
    final rows =
        await (_db.select(_db.taskInstances)
              ..where((t) => t.templateId.equals(templateId))
              ..orderBy([(t) => OrderingTerm.desc(t.occurrenceDate)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.occurrenceDate;
  }

  @override
  Future<void> upsertInstance(TaskTemplate template, DateTime date) async {
    // 已存在（含软删除）则不做任何修改 —— 禁止覆盖用户已有的计时/完成状态（禁止清单第 2 条）
    final existing =
        await (_db.select(_db.taskInstances)..where(
              (t) =>
                  t.templateId.equals(template.id) &
                  t.occurrenceDate.equals(engine.dateOnly(date)),
            ))
            .getSingleOrNull();
    if (existing != null) return;

    await _db
        .into(_db.taskInstances)
        .insert(
          TaskInstancesCompanion.insert(
            templateId: template.id,
            occurrenceDate: engine.dateOnly(date),
            titleSnapshot: template.title,
            typeSnapshot: template.type.name,
            caloriePerMinuteSnapshot: Value(template.caloriePerMinute),
            status: TaskStatus.todo.name,
          ),
        );
  }
}
