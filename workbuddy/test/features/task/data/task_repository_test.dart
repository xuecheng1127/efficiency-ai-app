import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/task/data/task_repository_impl.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/engine/backfill.dart';

void main() {
  group('TaskRepository 数据库集成测试（D1–D8，内存 SQLite）', () {
    late AppDatabase db;
    late TaskRepositoryImpl repo;

    // 固定日期，避免测试依赖真实时间
    final today = DateTime(2026, 10, 15);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TaskRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertTemplate({
      String title = '测试任务',
      RepeatMode mode = RepeatMode.daily,
      DateTime? startDate,
    }) {
      return db
          .into(db.taskTemplates)
          .insert(
            TaskTemplatesCompanion.insert(
              type: TaskType.study.name,
              title: title,
              repeatMode: mode.name,
              startDate: startDate ?? today,
            ),
          );
    }

    Future<int> countInstances() async {
      final rows = await db.select(db.taskInstances).get();
      return rows.length;
    }

    test('D1: 幂等性 —— backfill 连续 3 次行数不变', () async {
      await insertTemplate();
      await repo.backfill(today);
      await repo.backfill(today);
      await repo.backfill(today);
      expect(await countInstances(), 1);
    });

    test('D2: 首次补齐恰好 1 条当日实例', () async {
      await insertTemplate();
      await repo.backfill(today);
      expect(await countInstances(), 1);
    });

    test('D3: startDate 3 天前 → 补齐 4 条（含今天）', () async {
      await insertTemplate(startDate: today.subtract(const Duration(days: 3)));
      await repo.backfill(today);
      expect(await countInstances(), 4);
    });

    test('D4: 唯一索引生效 —— 手工插重复抛约束错误', () async {
      final id = await insertTemplate();
      await repo.backfill(today);
      expect(
        () => db
            .into(db.taskInstances)
            .insert(
              TaskInstancesCompanion.insert(
                templateId: id,
                occurrenceDate: today,
                titleSnapshot: '重复',
                typeSnapshot: TaskType.study.name,
                status: TaskStatus.todo.name,
              ),
            ),
        throwsA(anything),
      );
    });

    test('D5: 快照隔离 —— 改模板标题不影响历史实例', () async {
      final id = await insertTemplate(title: '原标题');
      await repo.backfill(today);
      await (db.update(db.taskTemplates)..where((t) => t.id.equals(id))).write(
        TaskTemplatesCompanion(title: Value('新标题')),
      );
      await repo.backfill(today);
      final inst = await (db.select(
        db.taskInstances,
      )..where((t) => t.templateId.equals(id))).getSingle();
      expect(inst.titleSnapshot, '原标题');
    });

    test('D6: 软删除不被复活', () async {
      final id = await insertTemplate();
      await repo.backfill(today);
      final inst = await (db.select(
        db.taskInstances,
      )..where((t) => t.templateId.equals(id))).getSingle();
      await (db.update(db.taskInstances)..where((t) => t.id.equals(inst.id)))
          .write(TaskInstancesCompanion(deletedAt: Value(DateTime.now())));
      await repo.backfill(today);
      // 仍是软删除那一条，没有新增（不复活）
      expect(await countInstances(), 1);
    });

    test('D7: 归档模板不再生成', () async {
      final id = await insertTemplate();
      await (db.update(db.taskTemplates)..where((t) => t.id.equals(id))).write(
        TaskTemplatesCompanion(archivedAt: Value(DateTime.now())),
      );
      await repo.backfill(today);
      expect(await countInstances(), 0);
    });

    test('D8: 上限保护 —— startDate 365 天前', () async {
      await insertTemplate(
        startDate: today.subtract(const Duration(days: 365)),
      );
      await repo.backfill(today);
      expect(await countInstances(), lessThanOrEqualTo(maxBackfillDays));
    });
  });
}
