import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:location/location.dart' as loc;

import '../../../core/database/app_database.dart';
import 'loc_notification_service.dart';

/// 途径提醒前台服务
///
/// 方案：用 flutter_foreground_task 起一个常驻前台服务（通知栏常驻
/// 「途径提醒运行中」），但实际位置检查在主 isolate 的 Timer 里跑。
/// 前台服务保活让主 isolate 切后台后不被系统杀掉。
class LocationFgService {
  static const int _serviceId = 257;
  static const String channelId = 'location_reminder_service';

  static Timer? _timer;
  static loc.Location? _location;
  static AppDatabase? _db;
  static bool _running = false;

  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: channelId,
        channelName: '途径提醒',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void _callback() {
    FlutterForegroundTask.setTaskHandler(_EmptyHandler());
  }

  static Future<void> start(AppDatabase db) async {
    if (_running) return;
    _running = true;
    _db = db;
    _location = loc.Location();

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: '途径提醒运行中',
      notificationText: '正在后台监控你设置的地点',
      callback: _callback,
    );

    // 主 isolate 里 60 秒轮询
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _check());
    // 启动时立刻查一次
    unawaited(_check());
  }

  static Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static bool get isRunning => _running;

  static Future<void> _check() async {
    try {
      debugPrint('[途径提醒] 轮询开始 ${DateTime.now()}');
      final location = _location;
      final db = _db;
      if (location == null || db == null) {
        debugPrint('[途径提醒] location/db 为空，跳过');
        return;
      }
      final enabled = await location.serviceEnabled();
      debugPrint('[途径提醒] 定位服务 enabled=$enabled');
      if (!enabled) return;
      final pos = await location.getLocation();
      final lat = pos.latitude;
      final lon = pos.longitude;
      debugPrint('[途径提醒] 取到位置 lat=$lat lon=$lon');
      if (lat == null || lon == null) return;

      final rows = await (db.select(db.locationReminders)
            ..where((t) => t.enabled.equals(1) & t.deletedAt.isNull()))
          .get();
      debugPrint('[途径提醒] enabled 提醒 ${rows.length} 条');

      for (final r in rows) {
        final dx = (lat - r.latitude) * 111000;
        final dy = (lon - r.longitude) * 111000 * 0.86;
        final dist2 = dx * dx + dy * dy;
        debugPrint('[途径提醒] ${r.placeName} 距离²=$dist2 阈值²=${r.radiusMeters * r.radiusMeters}');
        if (dist2 < r.radiusMeters * r.radiusMeters) {
          final last = r.notifiedAt;
          if (last != null &&
              DateTime.now().millisecondsSinceEpoch - last <
                  24 * 3600 * 1000) {
            debugPrint('[途径提醒] 24h 内已通知，跳过');
            continue;
          }
          await LocNotificationService().show(
            id: r.id,
            title: '途径提醒',
            body: '你正在【${r.placeName}】附近 —— ${r.title}',
          );
          debugPrint('[途径提醒] 已发通知 ${r.placeName}');
          await (db.update(db.locationReminders)
                ..where((t) => t.id.equals(r.id)))
              .write(
            LocationRemindersCompanion(
              notifiedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }
      }
    } catch (e, st) {
      debugPrint('[途径提醒] 异常: $e\n$st');
    }
  }
}

class _EmptyHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool appKilled) async {}
}
