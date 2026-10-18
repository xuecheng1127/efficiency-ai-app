import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/notifications/app_notifications.dart';
import 'core/platform/alarm_channel.dart';
import 'core/settings/app_settings.dart';
import 'features/alarm/alarm_log.dart';
import 'features/alarm/data/alarm_repository_impl.dart';
import 'features/birthday/application/birthday_reminders.dart';
import 'features/birthday/data/birthday_repository_impl.dart';
import 'features/task/data/task_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 打开数据库（存放于应用专属目录，后台 isolate 执行）
  final db = await AppDatabase.open();

  // 惰性补齐今日及缺失实例（幂等，可安全重复执行，见 T01 规格 §3）
  await TaskRepositoryImpl(db).backfill(DateTime.now());

  // T10 证据 #5：进程启动时从 scheduled_alarms 表完整读回闹钟并打印。
  // 这里是全新进程（设备重启/杀进程后仅剩持久化数据），打印出来的内容
  // 只可能来自数据库，不可能是内存或 Intent 残留。
  final alarmRepository = AlarmRepositoryImpl(db);
  final alarms = await alarmRepository.loadAll();
  final report = StringBuffer(
    'startup reload: ${alarms.length} alarm(s) from table scheduled_alarms',
  );
  for (final a in alarms) {
    report.write('\n  - $a');
  }
  alarmLog(report.toString());

  // T10.5：把原生闹钟层接上。这里调用的两个方法都是**只读 / 幂等**的：
  // - canScheduleExactAlarms：读当前档位（PRD v2 §3.3「界面必须如实告知当前档位」的数据来源）；
  // - rescheduleAll：按表重建未来闹钟（参数一律来自 scheduled_alarms，不走 Intent extra）。
  //   进程被杀后闹钟仍在系统侧，但「重启手机」会清空 —— 开机重建是 T11 的 BootReceiver，
  //   这里只做「打开 App 时对齐一次」，不改动任何业务数据。
  try {
    final exact = await AlarmScheduler.canScheduleExactAlarms();
    alarmNativeLog(
      'startup probe canScheduleExactAlarms=$exact => '
      '${exact ? "档位 A 精确（setExactAndAllowWhileIdle）" : "档位 B 近似（setWindow 60s）"}',
    );
    await AlarmScheduler.rescheduleAll();
    alarmNativeLog(
      'startup rescheduleAll invoked (parameter source = scheduled_alarms table)',
    );
  } catch (e) {
    alarmNativeLog('native alarm channel unavailable: $e');
  }

  // T11：清理「已经过去的一次性闹钟」。
  //
  // 注意执行顺序 —— **先让原生 rescheduleAll 跑完，再做这里的清理**：
  // 原生会先打一条 `skip: once already expired` 的日志（证明它确实跳过了重排、没有「凭空响一声」），
  // 然后 Dart 再把这条永远不会触发的记录从表里删掉（表的写入方是 Dart，原生对表只读）。
  // 两步都留日志，评审方可以对照着看。
  await alarmRepository.pruneExpiredOnce(DateTime.now());

  // 工具箱插件：本地通知 + 生日提醒重排。
  //
  // 为什么放在启动时：定时通知是**系统侧**登记的，用户改月日/改提前天数后重排过，
  // 但「跨年 / 改系统时间 / 重装后恢复」这些场景只能靠每次启动对齐一次。
  // 通知初始化失败不影响启动（内部已吞异常）。
  try {
    await AppNotifications.init();
    final birthdays = await BirthdayRepositoryImpl(db).all();
    await BirthdayReminders.syncAll(birthdays);
  } catch (e) {
    alarmLog('birthday reminder sync skipped: $e');
  }

  // T-UI：设置存储（`app_settings.json`）。
  // 在 runApp 之前打开，保证 UI 首帧就能读到真实设置（不会先闪一下默认值）。
  final settingsStore = await SettingsStore.open();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(settingsStore),
      ],
      child: const App(),
    ),
  );
}
