import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/task/data/task_mapper.dart';
import 'package:efficiency_app/features/task/data/task_repository_impl.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_instance.dart';
import 'package:flutter_test/flutter_test.dart';

/// PHONE-FIX-1 · 计时暂停（仓库层 + 领域计算）。
///
/// 用户原话：「打开任务计时的时候还不能暂停，只能取消或者已完成」。
/// 暂停态**不新增 status 值**：`inProgress` + `startedAt == null` 就是暂停，
/// 已跑秒数结算进 `accumulatedSeconds`。
void main() {
  group('暂停 / 继续（仓库层，内存 SQLite）', () {
    late AppDatabase db;
    late TaskRepositoryImpl repo;
    final today = DateTime(2026, 10, 29);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TaskRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seed() async {
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

    /// 直接摆一个「已在跑 secondsAgo 秒、之前已归档 archived 秒」的实例。
    /// 不走 sleep：测试要快，也不能靠真实时钟。
    Future<int> runningWith({
      required int secondsAgo,
      required int archived,
    }) async {
      final id = await seed();
      await (db.update(db.taskInstances)..where((t) => t.id.equals(id))).write(
        TaskInstancesCompanion(
          status: const Value('inProgress'),
          startedAt: Value(
            DateTime.now().subtract(Duration(seconds: secondsAgo)),
          ),
          accumulatedSeconds: Value(archived),
        ),
      );
      return id;
    }

    test('暂停：本段秒数结算进 accumulatedSeconds，startedAt 清空、状态仍是 inProgress',
        () async {
      final id = await runningWith(secondsAgo: 5, archived: 10);

      await repo.pauseTimer(id);
      final row = await read(id);

      expect(row.status, TaskStatus.inProgress, reason: '暂停不是取消，状态不能退回 todo');
      expect(row.startedAt, isNull, reason: '暂停态由 startedAt 为空表达');
      expect(row.accumulatedSeconds, inInclusiveRange(14, 17), reason: '10 + 约 5 秒');
      expect(row.isPaused, isTrue);
      expect(row.isRunning, isFalse);
    });

    test('暂停是幂等的：连点两次不会把同一段时间结算两遍', () async {
      final id = await runningWith(secondsAgo: 5, archived: 0);

      await repo.pauseTimer(id);
      final once = (await read(id)).accumulatedSeconds;
      await repo.pauseTimer(id);
      final twice = (await read(id)).accumulatedSeconds;

      expect(twice, once, reason: '第二次暂停必须什么都不做');
      expect(once, inInclusiveRange(4, 7));
    });

    test('继续：接上新的起点，累计秒数不清零', () async {
      final id = await runningWith(secondsAgo: 5, archived: 0);
      await repo.pauseTimer(id);
      final paused = await read(id);

      await repo.resumeTimer(id);
      final resumed = await read(id);

      expect(resumed.startedAt, isNotNull, reason: '继续 = 重新种一个起点');
      expect(resumed.accumulatedSeconds, paused.accumulatedSeconds, reason: '累计不能被继续清零');
      expect(resumed.status, TaskStatus.inProgress);
      expect(resumed.isRunning, isTrue);

      // 从暂停处接着涨，而不是从 0
      final elapsed = resumed.elapsedSecondsAt(
        resumed.startedAt!.add(const Duration(seconds: 3)),
      );
      expect(elapsed, paused.accumulatedSeconds + 3);
    });

    test('继续是幂等的：已经在跑时不会把起点往回拨', () async {
      final id = await runningWith(secondsAgo: 30, archived: 0);
      final before = (await read(id)).startedAt;

      await repo.resumeTimer(id);
      final after = (await read(id)).startedAt;

      expect(
        after!.difference(before!).inSeconds.abs(),
        lessThanOrEqualTo(1),
        reason: '已在跑的条目被 resume 不能重置起点（否则这一段秒数白跑）',
      );
    });

    test('已完成不会被 pause / resume 拉起来', () async {
      final id = await seed();
      await repo.completeInstance(id);
      await repo.pauseTimer(id);
      await repo.resumeTimer(id);

      final row = await read(id);
      expect(row.status, TaskStatus.done);
      expect(row.startedAt, isNull);
    });

    test('暂停中完成：归档耗时 = 已累计秒数，不含暂停时间', () async {
      final id = await runningWith(secondsAgo: 5, archived: 100);
      await repo.pauseTimer(id);
      await repo.completeInstance(id);

      final row = await read(id);
      expect(row.status, TaskStatus.done);
      expect(row.accumulatedSeconds, inInclusiveRange(104, 107));
    });

    test('取消计时不再丢弃已跑秒数（旧版直接归零）', () async {
      final id = await runningWith(secondsAgo: 5, archived: 3);

      await repo.cancelTimer(id);
      final row = await read(id);

      expect(row.status, TaskStatus.todo);
      expect(row.startedAt, isNull);
      expect(row.accumulatedSeconds, inInclusiveRange(7, 10));
    });
  });

  group('已耗时计算（纯函数，不碰时钟）', () {
    TaskInstance make({
      required TaskStatus status,
      DateTime? startedAt,
      int accumulated = 0,
    }) {
      return TaskInstance(
        id: 1,
        templateId: 1,
        occurrenceDate: DateTime(2026, 10, 29),
        titleSnapshot: '背单词',
        typeSnapshot: TaskType.study,
        status: status,
        startedAt: startedAt,
        accumulatedSeconds: accumulated,
      );
    }

    final t0 = DateTime(2026, 10, 29, 10);

    test('计时中：累计 + 本段', () {
      final item = make(
        status: TaskStatus.inProgress,
        startedAt: t0,
        accumulated: 30,
      );
      expect(item.elapsedSecondsAt(t0.add(const Duration(seconds: 12))), 42);
    });

    test('已暂停：只有累计，时间再往前走也不变', () {
      final item = make(
        status: TaskStatus.inProgress,
        accumulated: 30,
      );
      expect(item.elapsedSecondsAt(t0), 30);
      expect(item.elapsedSecondsAt(t0.add(const Duration(hours: 2))), 30);
    });

    test('未开始 / 已完成：只有累计', () {
      expect(make(status: TaskStatus.todo).elapsedSecondsAt(t0), 0);
      expect(
        make(status: TaskStatus.done, accumulated: 125).elapsedSecondsAt(t0),
        125,
      );
    });

    test('时钟被回拨（now < startedAt）时不出现负数', () {
      final item = make(
        status: TaskStatus.inProgress,
        startedAt: t0,
        accumulated: 5,
      );
      expect(
        item.elapsedSecondsAt(t0.subtract(const Duration(minutes: 10))),
        5,
      );
    });
  });
}
