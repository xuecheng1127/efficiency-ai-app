import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/task/data/task_repository_impl.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_template.dart';
import 'package:efficiency_app/features/task/engine/backfill.dart';
import 'package:flutter_test/flutter_test.dart';

/// D1–D8：数据库集成测试（规格 §5.2，内存 SQLite）
///
/// 使用 `AppDatabase(NativeDatabase.memory())` + [TaskRepositoryImpl]，
/// 真实走 Drift 表 / 唯一索引 / 快照 / 软删除语义。
void main() {
  late AppDatabase db;
  late TaskRepositoryImpl repo;
  final today = DateTime(2026, 10, 15);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TaskRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('D1 幂等性', () {
    test('同一 backfill 连续调用 3 次，task_instances 行数不变', () async {
      final tpl = _daily('每日健身', today);
      await repo.addTask(tpl);

      await repo.backfillOnAppStart(today);
      final after1 = await _instanceCount(db);
      expect(after1, 1, reason: '首次补齐应生成 1 条当日实例');

      await repo.backfillOnAppStart(today);
      await repo.backfillOnAppStart(today);
      final after3 = await _instanceCount(db);
      expect(after3, after1, reason: '重复补齐不得新增行（依赖 UNIQUE 索引）');
    });
  });

  group('D2 首次补齐', () {
    test('新 daily 模板一次调用恰好生成 1 条当日实例', () async {
      final tpl = _daily('每日学习', today);
      final id = await repo.addTask(tpl);

      await repo.backfillOnAppStart(today);
      expect(await _instanceCount(db), 1);

      final occ = await repo.getOccurrence(id, today);
      expect(occ, isNotNull);
      expect(occ!.titleSnapshot, '每日学习');
      expect(occ.typeSnapshot, TaskType.study);
      expect(occ.status, TaskStatus.todo);
      expect(occ.accumulatedSeconds, 0);
    });
  });

  group('D3 补历史', () {
    test('startDate 为 3 天前 → 一次补齐 4 条（含今天）', () async {
      final start = today.subtract(const Duration(days: 3));
      final tpl = _daily('三日任务', start);
      await repo.addTask(tpl);

      await repo.backfillOnAppStart(today);
      expect(await _instanceCount(db), 4,
          reason: 'startDate..today 共 4 天，daily 全命中');
    });
  });

  group('D4 唯一约束生效', () {
    test('手工插入重复 (templateId, occurrenceDate) 抛约束错误', () async {
      final tpl = _daily('约束测试', today);
      final id = await repo.addTask(tpl);
      final companion = TaskInstancesCompanion.insert(
        templateId: id,
        occurrenceDate: today,
        titleSnapshot: 'A',
        typeSnapshot: TaskType.study.name,
        status: TaskStatus.todo.name,
      );

      await db.into(db.taskInstances).insert(companion);
      expect(
        () => db.into(db.taskInstances).insert(companion),
        throwsA(isA<Exception>()),
        reason: '第二次插入相同键必须触发 UNIQUE 约束（红线 3）',
      );
    });
  });

  group('D5 快照隔离', () {
    test('生成实例后改模板 title → 再补齐，已有实例 titleSnapshot 不变', () async {
      final tpl = _daily('旧标题', today);
      final id = await repo.addTask(tpl);
      final tplWithId = tpl.copyWith(id: id);

      await repo.backfillOnAppStart(today);
      final before = (await repo.getOccurrence(id, today))!;
      expect(before.titleSnapshot, '旧标题');

      // 改模板标题（快照原则：不应影响已生成实例）
      await repo.updateTask(tplWithId.copyWith(title: '新标题'));
      await repo.backfillOnAppStart(today);

      final after = (await repo.getOccurrence(id, today))!;
      expect(after.titleSnapshot, '旧标题',
          reason: '改模板不得篡改历史实例快照（红线 5）');
      // 且不产生新行
      expect(await _instanceCount(db), 1);
    });
  });

  group('D6 软删除不复活', () {
    test('实例设 deletedAt → 再补齐不重新创建', () async {
      final tpl = _daily('删除测试', today);
      final id = await repo.addTask(tpl);

      await repo.backfillOnAppStart(today);
      expect(await _instanceCount(db), 1);

      // 实例级软删除
      final occ = (await repo.getOccurrence(id, today))!;
      await (db.update(db.taskInstances)..where((i) => i.id.equals(occ.id!)))
          .write(TaskInstancesCompanion(
        deletedAt: Value(DateTime.now()),
      ));

      // 再补齐：不得复活该实例（upsert 必须检查含软删除行，红线 2）
      await repo.backfillOnAppStart(today);
      expect(await _instanceCount(db), 1, reason: '软删除实例不得被重新创建');

      // 且该行 deletedAt 仍非空
      final all = await db.select(db.taskInstances).get();
      expect(all.single.deletedAt, isNotNull);
    });
  });

  group('D7 归档模板不再生成', () {
    test('模板设 archivedAt → 再补齐不产生新实例', () async {
      final tpl = _daily('归档测试', today);
      final id = await repo.addTask(tpl);

      await repo.backfillOnAppStart(today);
      expect(await _instanceCount(db), 1);

      await repo.archiveTask(id);
      await repo.backfillOnAppStart(today);
      expect(await _instanceCount(db), 1,
          reason: '归档模板不产生新实例（loadActiveTemplates 过滤 archivedAt）');
    });
  });

  group('D8 上限保护', () {
    test('startDate 为 365 天前 → 一次补齐实例数 ≤ MAX_BACKFILL_DAYS', () async {
      final start = today.subtract(const Duration(days: 365));
      final tpl = _daily('远古任务', start);
      await repo.addTask(tpl);

      await repo.backfillOnAppStart(today);
      final count = await _instanceCount(db);
      expect(count, lessThanOrEqualTo(kMaxBackfillDays),
          reason: '一次补齐不得超过 MAX_BACKFILL_DAYS（红线 7），实际 $count');
    });
  });

  group('D9 回归：startDate 带时分秒', () {
    test('startDate 带时分秒时重复补齐全幂等（不再撞 UNIQUE）', () async {
      // 真实 bug：startDate = DateTime(2026,10,17, 1,8,32) 带时分秒
      // 查询归一化到 0 点但插入没归一化 → 每次启动重插 → UNIQUE 冲突
      final startWithTime = DateTime(2026, 10, 15, 1, 8, 32);
      final tpl = TaskTemplate(
        type: TaskType.study,
        title: '带时分秒任务',
        repeatMode: RepeatRule.daily,
        startDate: startWithTime,
        createdAt: startWithTime,
      );
      await repo.addTask(tpl);

      // 第一次补齐
      await repo.backfillOnAppStart(today);
      final after1 = await _instanceCount(db);
      expect(after1, 1);

      // 第二次补齐：修复前会抛 UNIQUE constraint failed
      await repo.backfillOnAppStart(today);
      await repo.backfillOnAppStart(today);
      final after3 = await _instanceCount(db);
      expect(after3, 1,
          reason: 'startDate 带时分秒时重复补齐不得撞 UNIQUE');
    });
  });

  // ==================== 辅助 ====================
}

Future<int> _instanceCount(AppDatabase db) async {
  final rows = await db.select(db.taskInstances).get();
  return rows.length;
}

TaskTemplate _daily(String title, DateTime start) {
  return TaskTemplate(
    type: TaskType.study,
    title: title,
    repeatMode: RepeatRule.daily,
    startDate: start,
    createdAt: start,
  );
}