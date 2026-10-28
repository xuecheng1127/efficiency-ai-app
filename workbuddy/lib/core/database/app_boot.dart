import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/alarm/alarm_log.dart';
import '../../features/alarm/data/alarm_repository_impl.dart';
import '../../features/birthday/application/birthday_reminders.dart';
import '../../features/birthday/data/birthday_repository_impl.dart';
import '../../features/task/data/task_repository_impl.dart';
import '../notifications/app_notifications.dart';
import '../platform/alarm_channel.dart';
import '../settings/app_settings.dart';
import 'app_database.dart';

/// 启动成功后的产物：把「已经准备好」的东西原样交给 UI。
class BootResult {
  const BootResult({
    required this.db,
    required this.settings,
    required this.dbFile,
  });

  final AppDatabase db;
  final SettingsStore settings;
  final File dbFile;
}

/// 启动流程（从 `main()` 里搬出来的）。
///
/// 为什么搬：原来的 `main()` 是「一路 await 到底，任何一步抛异常，
/// `runApp` 就永远不会执行」——数据库文件坏一个字节，用户看到的就是
/// 一个停在 Flutter logo 上的白屏，连重试的入口都没有。
///
/// 现在它返回 Future，由 [BootstrapApp] 接住失败并渲染错误页。
///
/// 顺序与旧 `main()` 完全一致（惰性 backfill → 闹钟对齐 → 清洗过期一次性闹钟
/// → 通知/生日重排 → 设置），保证「重启后行为」没有变化。
Future<BootResult> bootApp({File? dbFile, SettingsStore? settingsOverride}) async {
  final file = dbFile ?? await AppDatabase.defaultFile();

  final db = await AppDatabase.open(file: file);
  try {
    await AppDatabase.assertReadable(db);
  } catch (_) {
    // 打不开就把连接关掉，别让损坏文件继续被持有（恢复时要改名）。
    await db.close();
    rethrow;
  }

  // 惰性补齐今日及缺失实例（幂等，可安全重复执行，见 T01 规格 §3）
  await TaskRepositoryImpl(db).backfill(DateTime.now());

  // T10 证据 #5：进程启动时从 scheduled_alarms 表完整读回闹钟并打印。
  final alarmRepository = AlarmRepositoryImpl(db);
  final alarms = await alarmRepository.loadAll();
  final report = StringBuffer(
    'startup reload: ${alarms.length} alarm(s) from table scheduled_alarms',
  );
  for (final a in alarms) {
    report.write('\n  - $a');
  }
  alarmLog(report.toString());

  // T10.5：把原生闹钟层接上（只读 / 幂等）。
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

  // T11：清理「已经过去的一次性闹钟」（原生先跳过，Dart 再删记录）。
  await alarmRepository.pruneExpiredOnce(DateTime.now());

  // 工具箱插件：本地通知 + 生日提醒重排（失败不影响启动）。
  try {
    await AppNotifications.init();
    final birthdays = await BirthdayRepositoryImpl(db).all();
    await BirthdayReminders.syncAll(birthdays);
  } catch (e) {
    alarmLog('birthday reminder sync skipped: $e');
  }

  // 设置存储：在 runApp 之前打开，保证 UI 首帧就是真实设置。
  final settings = settingsOverride ?? await SettingsStore.open();

  debugPrint('[Boot] database ready: ${file.path}');
  return BootResult(db: db, settings: settings, dbFile: file);
}
