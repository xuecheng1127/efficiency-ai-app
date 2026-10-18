import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/alarm/data/alarm_repository_impl.dart';
import 'package:efficiency_app/features/alarm/domain/alarm_enums.dart';
import 'package:efficiency_app/features/alarm/domain/scheduled_alarm.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AlarmRepository 持久化测试（A1–A10，内存 SQLite）', () {
    late AppDatabase db;
    late AlarmRepositoryImpl repo;

    setUpAll(() {
      // A4 需要「同一文件被两个 AppDatabase 实例先后打开」来模拟进程重启，
      // drift 对此默认告警；这里是有意为之，显式关闭该提示（不影响任何断言）。
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = AlarmRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertTemplate({String title = '早读'}) {
      return db.into(db.taskTemplates).insert(
            TaskTemplatesCompanion.insert(
              type: TaskType.study.name,
              title: title,
              repeatMode: RepeatMode.daily.name,
              startDate: DateTime(2026, 10, 16),
            ),
          );
    }

    Future<int> countAlarms() async {
      final rows = await db.select(db.scheduledAlarms).get();
      return rows.length;
    }

    test('A1: 调度即落盘 —— 11 个必持久化字段逐项正确', () async {
      final taskId = await insertTemplate();

      final saved = await repo.scheduleForTask(
        taskId: taskId,
        hour: 7,
        minute: 5,
        repeatRule: 'weekly',
        weekdays: const [1, 3, 5],
        advanceMinutes: 15,
        ringtone: 'gentle_bell',
        volume: 65,
        snoozeEnabled: true,
        snoozeMinutes: 10,
        tier: AlarmTier.exact,
      );

      final row = await (db.select(db.scheduledAlarms)
            ..where((t) => t.id.equals(saved.id)))
          .getSingle();
      expect(row.taskId, taskId);
      expect(row.hour, 7);
      expect(row.minute, 5);
      expect(row.repeatRule, 'weekly');
      expect(row.weekdays, '1,3,5');
      expect(row.advanceMinutes, 15);
      expect(row.ringtone, 'gentle_bell');
      expect(row.volume, 65);
      expect(row.snoozeEnabled, isTrue);
      expect(row.snoozeMinutes, 10);
      expect(row.tier, 'exact');
      expect(row.enabled, isTrue);
    });

    test('A2: 重复调度同一任务 —— 覆盖而非新增', () async {
      final taskId = await insertTemplate();

      await repo.scheduleForTask(
        taskId: taskId,
        hour: 7,
        minute: 0,
        repeatRule: 'daily',
      );
      await repo.scheduleForTask(
        taskId: taskId,
        hour: 21,
        minute: 30,
        repeatRule: 'daily',
        volume: 40,
      );

      expect(await countAlarms(), 1);
      final only = (await repo.loadAll()).single;
      expect(only.hour, 21);
      expect(only.minute, 30);
      expect(only.volume, 40);
    });

    test('A3: UNIQUE(task_id) 生效 —— 手工插重复抛约束错误', () async {
      final taskId = await insertTemplate();
      await repo.scheduleForTask(
        taskId: taskId,
        hour: 7,
        minute: 0,
        repeatRule: 'daily',
      );

      expect(
        () => db.into(db.scheduledAlarms).insert(
              ScheduledAlarmsCompanion.insert(
                taskId: taskId,
                hour: 8,
                minute: 0,
                repeatRule: 'daily',
              ),
            ),
        throwsA(anything),
      );
    });

    test('A4: 杀进程重启模拟 —— 关闭数据库后重开，逐字段一致', () async {
      final dir = Directory(
        p.join(Directory.current.path, '.dart_tool', 't10_restart_db'),
      );
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      final file = File(p.join(dir.path, 'efficiency_app.sqlite'));

      // ---- 第一次「进程」：写入 ----
      final db1 = AppDatabase(NativeDatabase(file));
      final taskId = await db1.into(db1.taskTemplates).insert(
            TaskTemplatesCompanion.insert(
              type: TaskType.study.name,
              title: '重启验证',
              repeatMode: RepeatMode.weekly.name,
              repeatDays: const Value('1,5'),
              startDate: DateTime(2026, 10, 16),
            ),
          );
      final before = await AlarmRepositoryImpl(db1).scheduleForTask(
        taskId: taskId,
        hour: 6,
        minute: 45,
        repeatRule: 'weekly',
        weekdays: const [5, 1],
        scheduledDate: DateTime(2026, 10, 16),
        advanceMinutes: 30,
        ringtone: 'soft_wind',
        volume: 33,
        snoozeEnabled: false,
        snoozeMinutes: 15,
        tier: AlarmTier.inApp,
      );
      await db1.close(); // 等价于进程被杀：连接关闭，内存态全部消失

      // ---- 第二次「进程」：只凭磁盘上的库读回 ----
      final db2 = AppDatabase(NativeDatabase(file));
      final after = (await AlarmRepositoryImpl(db2).loadAll()).single;

      expect(after.taskId, before.taskId);
      expect(after.hour, before.hour);
      expect(after.minute, before.minute);
      expect(after.repeatRule, before.repeatRule);
      expect(after.weekdays, before.weekdays);
      expect(after.scheduledDate, before.scheduledDate);
      expect(after.advanceMinutes, before.advanceMinutes);
      expect(after.ringtone, before.ringtone);
      expect(after.volume, before.volume);
      expect(after.snoozeEnabled, before.snoozeEnabled);
      expect(after.snoozeMinutes, before.snoozeMinutes);
      expect(after.tier, before.tier);
      expect(after.enabled, before.enabled);
      await db2.close();

      dir.deleteSync(recursive: true);
    });

    test('A5: cancel 删除记录', () async {
      final taskId = await insertTemplate();
      await repo.scheduleForTask(
        taskId: taskId,
        hour: 7,
        minute: 0,
        repeatRule: 'daily',
      );
      expect(await countAlarms(), 1);

      await repo.cancelForTask(taskId);
      expect(await countAlarms(), 0);
    });

    test('A6: 外键级联 —— 删除任务模板，闹钟记录自动清理', () async {
      final taskId = await insertTemplate();
      await repo.scheduleForTask(
        taskId: taskId,
        hour: 7,
        minute: 0,
        repeatRule: 'daily',
      );

      await (db.delete(db.taskTemplates)..where((t) => t.id.equals(taskId))).go();
      expect(await countAlarms(), 0);
    });

    test('A7: 表能独立枚举「待重建闹钟」（不依赖任何 Intent）', () async {
      final t1 = await insertTemplate(title: 'A');
      final t2 = await insertTemplate(title: 'B');
      await repo.scheduleForTask(
        taskId: t1,
        hour: 9,
        minute: 0,
        repeatRule: 'daily',
      );
      await repo.scheduleForTask(
        taskId: t2,
        hour: 6,
        minute: 0,
        repeatRule: 'daily',
      );
      // 手工把 t2 的闹钟置为「不参与重建」
      await (db.update(db.scheduledAlarms)..where((t) => t.taskId.equals(t2)))
          .write(const ScheduledAlarmsCompanion(enabled: Value(false)));

      final enabled = await repo.loadEnabled();
      expect(enabled.length, 1);
      expect(enabled.single.taskId, t1);
      // loadAll 仍能看到全部记录（记录保留）
      expect((await repo.loadAll()).length, 2);
    });

    test('A8: 三档档位可区分 + weekdays 往返', () async {
      final t1 = await insertTemplate(title: 'A');
      final t2 = await insertTemplate(title: 'B');
      final t3 = await insertTemplate(title: 'C');

      await repo.scheduleForTask(
        taskId: t1,
        hour: 1,
        minute: 0,
        repeatRule: 'daily',
        tier: AlarmTier.exact,
      );
      await repo.scheduleForTask(
        taskId: t2,
        hour: 2,
        minute: 0,
        repeatRule: 'daily',
        tier: AlarmTier.inexact,
      );
      await repo.scheduleForTask(
        taskId: t3,
        hour: 3,
        minute: 0,
        repeatRule: 'weekly',
        weekdays: const [7, 2, 4],
        tier: AlarmTier.inApp,
      );

      final all = await repo.loadAll();
      expect(all.map((a) => a.tier).toSet(), {
        AlarmTier.exact,
        AlarmTier.inexact,
        AlarmTier.inApp,
      });
      // weekdays 乱序写入 → 归一化后往返一致
      final weekly = all.firstWhere((a) => a.taskId == t3);
      expect(weekly.weekdays, const [2, 4, 7]);
    });

    test('A9: nextTriggerAt 推算（once / daily / weekly）', () {      final now = DateTime(2026, 10, 16, 8, 0); // 固定基准时间

      const base = ScheduledAlarm(
        id: 0,
        taskId: 1,
        hour: 0,
        minute: 0,
        repeatRule: 'daily',
      );

      // once：按 scheduledDate 原样取
      expect(
        ScheduledAlarm(
          id: 0,
          taskId: 1,
          hour: 7,
          minute: 30,
          repeatRule: 'once',
          scheduledDate: DateTime(2026, 11, 1),
        ).nextTriggerAt(now),
        DateTime(2026, 11, 1, 7, 30),
      );

      // daily：今天还没到 → 今天
      expect(
        const ScheduledAlarm(
          id: 0,
          taskId: 1,
          hour: 23,
          minute: 59,
          repeatRule: 'daily',
        ).nextTriggerAt(now),
        DateTime(2026, 10, 16, 23, 59),
      );

      // daily：今天已过 → 明天
      expect(
        const ScheduledAlarm(
          id: 0,
          taskId: 1,
          hour: 7,
          minute: 0,
          repeatRule: 'daily',
        ).nextTriggerAt(now),
        DateTime(2026, 10, 17, 7, 0),
      );

      // weekly：命中今天且未到点 → 今天
      expect(
        ScheduledAlarm(
          id: 0,
          taskId: 1,
          hour: 9,
          minute: 0,
          repeatRule: 'weekly',
          weekdays: [now.weekday],
        ).nextTriggerAt(now),
        DateTime(2026, 10, 16, 9, 0),
      );

      // weekly：命中今天但已过点 → 下同星期
      expect(
        ScheduledAlarm(
          id: 0,
          taskId: 1,
          hour: 7,
          minute: 0,
          repeatRule: 'weekly',
          weekdays: [now.weekday],
        ).nextTriggerAt(now),
        DateTime(2026, 10, 23, 7, 0),
      );

      // weekly：未命中今天 → 下一个命中的星期
      final tomorrow = now.add(const Duration(days: 1));
      expect(
        ScheduledAlarm(
          id: 0,
          taskId: 1,
          hour: 9,
          minute: 0,
          repeatRule: 'weekly',
          weekdays: [tomorrow.weekday],
        ).nextTriggerAt(now),
        DateTime(2026, 10, 17, 9, 0),
      );

      // 兜底分支不应抛异常
      expect(base.copyWithRepeat('monthly').nextTriggerAt(now), isNotNull);
    });

    test('A10: pruneExpiredOnce —— 只清理已过去的一次性闹钟（T11）', () async {
      final oncePast = await insertTemplate(title: 'once-past');
      final onceFuture = await insertTemplate(title: 'once-future');
      final daily = await insertTemplate(title: 'daily');

      final now = DateTime(2026, 10, 16, 12, 0);
      await repo.scheduleForTask(
        taskId: oncePast,
        hour: 7,
        minute: 0,
        repeatRule: 'once',
        scheduledDate: DateTime(2026, 10, 15),
      );
      await repo.scheduleForTask(
        taskId: onceFuture,
        hour: 23,
        minute: 0,
        repeatRule: 'once',
        scheduledDate: DateTime(2026, 10, 16),
      );
      await repo.scheduleForTask(
        taskId: daily,
        hour: 7,
        minute: 0,
        repeatRule: 'daily',
      );
      expect(await countAlarms(), 3);

      expect(await repo.pruneExpiredOnce(now), 1);
      expect(
        (await repo.loadAll()).map((a) => a.taskId).toSet(),
        {onceFuture, daily},
        reason: '未来的 once 与重复闹钟都不能被清',
      );

      // 幂等：再清一次没有变化
      expect(await repo.pruneExpiredOnce(now), 0);
      expect(await countAlarms(), 2);
    });
  });
}

/// 测试内的小工具：改重复规则（避免为测试在实体上加 copyWith）
extension on ScheduledAlarm {
  ScheduledAlarm copyWithRepeat(String rule) => ScheduledAlarm(
        id: id,
        taskId: taskId,
        hour: hour,
        minute: minute,
        repeatRule: rule,
        weekdays: weekdays,
        scheduledDate: scheduledDate,
        advanceMinutes: advanceMinutes,
        ringtone: ringtone,
        volume: volume,
        snoozeEnabled: snoozeEnabled,
        snoozeMinutes: snoozeMinutes,
        tier: tier,
        enabled: enabled,
      );
}
