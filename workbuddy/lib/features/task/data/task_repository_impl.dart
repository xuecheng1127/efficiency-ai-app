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
  Future<void> pauseTimer(int instanceId) async {
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.taskInstances,
      )..where((t) => t.id.equals(instanceId))).getSingleOrNull();
      if (row == null) return;
      final start = row.startedAt;

      // 没有在跑（未开始 / 已暂停 / 已完成）：什么都不做。
      // 幂等很重要 —— 按钮连点两下不能把同一段时间结算两遍。
      if (row.status != TaskStatus.inProgress.name || start == null) return;

      final seg = DateTime.now().difference(start).inSeconds;
      await (_db.update(
        _db.taskInstances,
      )..where((t) => t.id.equals(instanceId))).write(
        TaskInstancesCompanion(
          // 只累加正数：手机改过时间导致 now < start 时，不让累计秒数倒退
          accumulatedSeconds: Value(
            row.accumulatedSeconds + (seg > 0 ? seg : 0),
          ),
          startedAt: const Value<DateTime?>(null),
        ),
      );
    });
  }

  @override
  Future<void> resumeTimer(int instanceId) {
    // 两个条件都写在 WHERE 里：进行中 **且** 当前没有起点（= 暂停态）。
    // 已经在跑的不会被回拨（否则这一段的秒数就白跑了），
    // 已完成的也不会被重新拉起来。
    return (_db.update(_db.taskInstances)..where(
          (t) =>
              t.id.equals(instanceId) &
              t.status.equals('inProgress') &
              t.startedAt.isNull(),
        ))
        .write(TaskInstancesCompanion(startedAt: Value(DateTime.now())));
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
  Future<void> cancelTimer(int instanceId) async {
    // 取消也要结算本段秒数（此前直接丢掉 —— 「已经学了一小时，点取消就归零」）。
    // 已暂停的条目没有本段可结算，只是把状态退回未开始。
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.taskInstances,
      )..where((t) => t.id.equals(instanceId))).getSingleOrNull();
      if (row == null) return;

      final start = row.startedAt;
      final seg = start == null
          ? 0
          : DateTime.now().difference(start).inSeconds;

      await (_db.update(
        _db.taskInstances,
      )..where((t) => t.id.equals(instanceId))).write(
        TaskInstancesCompanion(
          status: const Value('todo'),
          startedAt: const Value<DateTime?>(null),
          accumulatedSeconds: Value(
            row.accumulatedSeconds + (seg > 0 ? seg : 0),
          ),
        ),
      );
    });
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
  Future<Map<int, DateTime>> lastOccurrenceDates() async {
    // 一条 SQL 取「每个模板的最大 occurrenceDate」。
    //
    // 不用 `WHERE template_id IN (...)`：模板可能上千个，会撞 SQLite 的
    // 绑定参数上限（老设备是 999）。整表 GROUP BY 只是一次索引扫描，
    // 比 1000 次跨 isolate 往返便宜两个数量级（R5 实测 3.1s → 40ms）。
    final maxDate = _db.taskInstances.occurrenceDate.max();
    final rows =
        await (_db.selectOnly(_db.taskInstances)
              ..addColumns([_db.taskInstances.templateId, maxDate])
              ..groupBy([_db.taskInstances.templateId]))
            .get();

    final result = <int, DateTime>{};
    for (final row in rows) {
      final id = row.read(_db.taskInstances.templateId);
      final date = row.read(maxDate);
      if (id != null && date != null) result[id] = date;
    }
    return result;
  }

  @override
  Future<void> insertInstances(List<engine.BackfillDraft> drafts) {
    // 批量插入，`insertOrIgnore` 对应原来的「已存在则不动」：
    // 软删除的行也占着 UNIQUE(templateId, occurrenceDate)，所以不会把用户
    // 删掉的实例又插回来（禁止清单第 2 条）。
    return _db.batch((batch) {
      batch.insertAll(
        _db.taskInstances,
        [
          for (final draft in drafts)
            TaskInstancesCompanion.insert(
              templateId: draft.template.id,
              occurrenceDate: engine.dateOnly(draft.date),
              titleSnapshot: draft.template.title,
              typeSnapshot: draft.template.type.name,
              caloriePerMinuteSnapshot: Value(
                draft.template.caloriePerMinute,
              ),
              status: TaskStatus.todo.name,
            ),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }
}
