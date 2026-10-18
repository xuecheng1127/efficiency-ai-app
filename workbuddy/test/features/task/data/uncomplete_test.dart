import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/task/data/task_mapper.dart';
import 'package:efficiency_app/features/task/data/task_repository_impl.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_instance.dart';
import 'package:flutter_test/flutter_test.dart';

/// UNDO-COMPLETE 回归：**已完成可以退回未完成**，且不误伤正在跑的计时。
///
/// 修的是真实缺陷：点一次「完成」就回不去了，没有撤销 = 没有容错。
void main() {
  group('取消完成（仓库层，内存 SQLite）', () {
    late AppDatabase db;
    late TaskRepositoryImpl repo;
    final today = DateTime(2026, 10, 18);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TaskRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    /// 造一条今日实例，返回实例 id。
    Future<int> seedInstance() async {
      final templateId = await db
          .into(db.taskTemplates)
          .insert(
            TaskTemplatesCompanion.insert(
              type: TaskType.study.name,
              title: '背单词',
              repeatMode: RepeatMode.daily.name,
              startDate: today,
            ),
          );
      await repo.backfill(today);
      final row = await (db.select(
        db.taskInstances,
      )..where((t) => t.templateId.equals(templateId))).getSingle();
      return row.id;
    }

    Future<TaskInstance> read(int id) async {
      final row = await (db.select(
        db.taskInstances,
      )..where((t) => t.id.equals(id))).getSingle();
      return TaskMapper.toInstance(row);
    }

    /// 直接写一条「已完成且有归档耗时」的实例（不走 sleep，测试才快且确定）。
    Future<void> makeDone(int id, {int archivedSeconds = 125}) async {
      await (db.update(db.taskInstances)..where((t) => t.id.equals(id))).write(
        TaskInstancesCompanion(
          status: const Value('done'),
          completedAt: Value(DateTime(2026, 10, 18, 9, 30)),
          startedAt: const Value<DateTime?>(null),
          accumulatedSeconds: Value(archivedSeconds),
        ),
      );
    }

    test('已完成 → 未完成：状态回退、完成时间清空、归档耗时清零', () async {
      final id = await seedInstance();
      await makeDone(id);

      final done = await read(id);
      expect(done.status, TaskStatus.done);
      expect(done.completedAt, isNotNull);
      expect(done.accumulatedSeconds, 125);

      await repo.uncompleteInstance(id);

      final back = await read(id);
      expect(back.status, TaskStatus.todo);
      expect(back.completedAt, isNull);
      expect(back.startedAt, isNull);
      // 验收 §4：取消完成后不留下上一次完成的耗时记录
      expect(back.accumulatedSeconds, 0);
    });

    test('误调用不会掐掉正在跑的计时（状态仍为 inProgress）', () async {
      final id = await seedInstance();
      await repo.startTimer(id);

      final running = await read(id);
      expect(running.status, TaskStatus.inProgress);
      expect(running.startedAt, isNotNull);

      // 只在 status='done' 时才生效，这里应该是空操作
      await repo.uncompleteInstance(id);

      final after = await read(id);
      expect(after.status, TaskStatus.inProgress);
      expect(after.startedAt, running.startedAt);
    });

    test('撤回后可以重新完成（不是单向门）', () async {
      final id = await seedInstance();
      await makeDone(id);
      await repo.uncompleteInstance(id);

      await repo.completeInstance(id);

      final again = await read(id);
      expect(again.status, TaskStatus.done);
      expect(again.completedAt, isNotNull);
    });
  });
}
