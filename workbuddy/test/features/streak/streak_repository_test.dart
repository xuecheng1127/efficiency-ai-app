import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/streak/data/streak_repository_impl.dart';
import 'package:efficiency_app/features/streak/domain/streak.dart';
import 'package:flutter_test/flutter_test.dart';

/// 火花数据源：只从 `task_instances` 的 `completed_at` 推导，不新增表。
void main() {
  group('StreakRepositoryImpl · 已完成日期集合', () {
    late AppDatabase db;
    late StreakRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = StreakRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedTemplate() {
      return db
          .into(db.taskTemplates)
          .insert(
            TaskTemplatesCompanion.insert(
              type: 'study',
              title: '每日背单词',
              repeatMode: 'daily',
              startDate: DateTime(2026, 10, 1),
            ),
          );
    }

    Future<void> seedInstance({
      required int templateId,
      required DateTime day,
      required String status,
      DateTime? completedAt,
    }) {
      return db
          .into(db.taskInstances)
          .insert(
            TaskInstancesCompanion.insert(
              templateId: templateId,
              occurrenceDate: streakDateOnly(day),
              titleSnapshot: '每日背单词',
              typeSnapshot: 'study',
              status: status,
              completedAt: Value(completedAt),
            ),
          );
    }

    test('只统计 status=done 且有 completed_at 的实例', () async {
      final t = await seedTemplate();
      await seedInstance(
        templateId: t,
        day: DateTime(2026, 10, 26),
        status: 'done',
        completedAt: DateTime(2026, 10, 26, 21, 30),
      );
      await seedInstance(
        templateId: t,
        day: DateTime(2026, 10, 27),
        status: 'done',
        completedAt: DateTime(2026, 10, 27, 9, 0),
      );
      // 未完成 / 进行中：不该出现在火花里
      await seedInstance(
        templateId: t,
        day: DateTime(2026, 10, 28),
        status: 'todo',
      );
      // 同一模板同一天只能有一个实例（UNIQUE 约束），进行中用另一个模板
      final t2 = await seedTemplate();
      await seedInstance(
        templateId: t2,
        day: DateTime(2026, 10, 28),
        status: 'inProgress',
      );

      final days = await repo.watchCompletedDays().first;

      expect(days, {DateTime(2026, 10, 26), DateTime(2026, 10, 27)});
    });

    test('同一天完成多个任务只算一天', () async {
      final t = await seedTemplate();
      await seedInstance(
        templateId: t,
        day: DateTime(2026, 10, 28),
        status: 'done',
        completedAt: DateTime(2026, 10, 28, 8),
      );
      // 第二个任务（另一个模板）同一天完成
      final t2 = await seedTemplate();
      await seedInstance(
        templateId: t2,
        day: DateTime(2026, 10, 28),
        status: 'done',
        completedAt: DateTime(2026, 10, 28, 22),
      );

      final days = await repo.watchCompletedDays().first;

      expect(days, hasLength(1));
      expect(days.single, DateTime(2026, 10, 28));
    });

    test('撤回完成（completed_at 清空 + status=todo）后当天不再计入', () async {
      final t = await seedTemplate();
      await seedInstance(
        templateId: t,
        day: DateTime(2026, 10, 27),
        status: 'done',
        completedAt: DateTime(2026, 10, 27, 10),
      );
      expect(await repo.watchCompletedDays().first, hasLength(1));

      await (db.update(db.taskInstances)).write(
        const TaskInstancesCompanion(
          status: Value('todo'),
          completedAt: Value<DateTime?>(null),
          accumulatedSeconds: Value(0),
        ),
      );

      expect(await repo.watchCompletedDays().first, isEmpty);
    });

    test('空库 → 空集合（页面显示 0，不抛错）', () async {
      expect(await repo.watchCompletedDays().first, isEmpty);
    });
  });
}
