import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import 'geo_trigger_engine.dart';
import 'loc_notification_service.dart';

/// 途径提醒后台前台服务（R4）
///
/// 架构：flutter_foreground_task 的 TaskHandler 运行在后台 isolate，
/// 60 秒一次 onRepeatEvent：
/// 1. 取定位（location.getLocation）
/// 2. 直连 Drift 读启用中的提醒（不依赖 provider）
/// 3. 用纯函数引擎 evaluateGeoCheck 判定状态翻转
/// 4. 翻转命中 → flutter_local_notifications 发通知
/// 5. inside/outside 状态存 SharedPreferences（跨轮次、跨重启）
/// TaskHandler 注册入口（AOT/JIT 均保留）
///
/// 必须是顶层函数（官方示例模式）：flutter_foreground_task 的后台引擎
/// 通过「库路径 + 函数名」解析入口，顶层函数的解析路径最短、最稳。
@pragma('vm:entry-point')
void locationReminderServiceCallback() {
  FlutterForegroundTask.setTaskHandler(_LocationReminderTaskHandler());
}

class LocationReminderFgService {
  static const int serviceId = 258;

  /// SharedPreferences 中存 inside 状态的前缀
  static const String insideKeyPrefix = 'geo_inside_';

  /// 是否已完成 init
  static bool _initialized = false;

  /// 初始化服务配置（通知渠道 / 心跳间隔）
  ///
  /// 注意：FlutterForegroundTask.init 是全局配置，计时器服务也调用它。
  /// 插件以「最后一次 init」的 options 为准，因此本方法必须紧跟
  /// startService 成对调用，避免把本服务的 60s 配置留给计时器，
  /// 或把计时器的 1s 配置留给本服务。
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_reminder_service',
        channelName: '途径提醒',
        channelDescription: '后台监测地点的服务常驻通知',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 60 秒轮询：电量与及时性的平衡点
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: false,
        allowWifiLock: false,
      ),
    );
  }

  /// 启动后台监测（不负责权限申请，调用方需已获得定位权限）
  static Future<void> start() async {
    await init();
    final count = await _enabledCount();
    if (count == 0) return; // 无启用提醒，不起服务

    if (await FlutterForegroundTask.isRunningService) {
      // 服务已在跑：更新常驻通知数字即可
      await FlutterForegroundTask.updateService(
        notificationTitle: '途径提醒运行中',
        notificationText: serviceNotificationText(count),
      );
      return;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: '途径提醒运行中',
      notificationText: serviceNotificationText(count),
      notificationInitialRoute: '/',
      callback: locationReminderServiceCallback,
    );
    if (result is ServiceRequestFailure) {
      debugPrint('[途径提醒服务] 启动失败: ${result.error}');
    }
  }

  /// 停止后台监测并清空状态记录
  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().toList()) {
      if (k.startsWith(insideKeyPrefix)) {
        await p.remove(k);
      }
    }
  }

  /// 同步启停：按「启用中的提醒数」决定服务状态
  static Future<void> sync() async {
    final count = await _enabledCount();
    if (count > 0) {
      await start();
    } else {
      await stop();
    }
  }

  static Future<int> _enabledCount() async {
    final db = AppDatabase.instance;
    final rows = await (db.select(db.locationReminders)
          ..where((t) => t.enabled.equals(1) & t.deletedAt.isNull()))
        .get();
    return rows.length;
  }

  /// 供 app.dart 启动恢复调用（带错误日志版）
  static Future<void> syncWithLogs() async {
    try {
      await sync();
    } catch (e, st) {
      debugPrint('[途径提醒服务] sync 异常: $e\n$st');
    }
  }
}

/// 后台 isolate 里的轮询处理器
class _LocationReminderTaskHandler extends TaskHandler {
  static const String _tag = '[途径提醒后台]';

  /// 缓存数据库连接（handler 生命周期内复用）
  AppDatabase? _db;

  GeolocatorAndroid? _geo;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 插件在 setTaskHandler 时已自动完成
    // WidgetsFlutterBinding.ensureInitialized() + DartPluginRegistrant
    // .ensureInitialized()（见 flutter_foreground_task_method_channel.dart
    // 的 setTaskHandler 实现），此处无需重复注册。
    debugPrint('$_tag 服务启动 starter=$starter');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _checkOnce().catchError((Object e, StackTrace st) {
      debugPrint('$_tag 轮询异常: $e\n$st');
    });
  }

  Future<void> _checkOnce() async {
    // 0) 定位插件（geolocator_android 的 method channel 不依赖 Activity，
    //    后台 isolate 可用；location 包需要 Activity 附加，已弃用）
    final geo = _geo ??= GeolocatorAndroid();
    final serviceEnabled =
        await geo.isLocationServiceEnabled().catchError((_) => false);
    if (!serviceEnabled) return;

    // 1) 取定位：getLastKnownPosition 缓存若足够新鲜（<45 秒）直接用，
    //    否则用 getCurrentPosition 强制刷新（best 精度 + 25s 超时）。
    //    —— 阈值必须严格小于 60s 轮询间隔：上一轮 getCurrentPosition 会把
    //    结果写入 fused 缓存，若阈值 ≥ 轮询间隔，本轮就会直接复用上一轮
    //    的旧值、跳过刷新，移动就永远检测不到（实测踩坑）。
    //    —— 精度必须用 best：模拟器/部分设备的 passive gps 只对
    //    PRIORITY_HIGH_ACCURACY 订阅推送，low/balanced 会一直超时。
    double? lat;
    double? lng;
    Position? stale;
    try {
      final last = await geo.getLastKnownPosition();
      if (last != null) {
        stale = last;
        final age = DateTime.now().difference(last.timestamp).abs();
        if (age.inSeconds < 45) {
          lat = last.latitude;
          lng = last.longitude;
        }
      }
    } catch (e) {
      debugPrint('$_tag getLastKnownPosition 失败: $e');
    }
    if (lat == null || lng == null) {
      try {
        final pos = await geo.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 25),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (e) {
        debugPrint('$_tag getCurrentPosition 失败: $e');
        // 刷新失败时退回陈旧缓存（有总比没有好）
        if (stale != null) {
          lat = stale.latitude;
          lng = stale.longitude;
        }
      }
    }
    if (lat == null || lng == null) {
      debugPrint('$_tag 无法获取定位，本轮跳过');
      return;
    }
    debugPrint('$_tag lat=$lat lng=$lng');

    // 2) 直连数据库读启用中的提醒
    final db = _db ??= AppDatabase();
    final rows = await (db.select(db.locationReminders)
          ..where((t) => t.enabled.equals(1) & t.deletedAt.isNull()))
        .get();
    if (rows.isEmpty) {
      debugPrint('$_tag 无启用提醒');
      return;
    }

    // 3) 读历史 inside 状态
    final prefs = await SharedPreferences.getInstance();
    final lastInside = <int, bool>{};
    for (final r in rows) {
      final v = prefs
          .getBool('${LocationReminderFgService.insideKeyPrefix}${r.id}');
      if (v != null) lastInside[r.id] = v;
    }

    // 4) 纯函数引擎判定
    final result = evaluateGeoCheck(GeoCheckInput(
      latitude: lat,
      longitude: lng,
      reminders: [
        for (final r in rows)
          GeoReminderInput(
            id: r.id,
            title: r.title,
            placeName: r.placeName,
            latitude: r.latitude,
            longitude: r.longitude,
            radiusMeters: r.radiusMeters,
            triggerOn: r.triggerOn,
          ),
      ],
      lastInside: lastInside,
    ));

    // 5) 写回状态
    for (final e in result.insideStates.entries) {
      await prefs.setBool(
        '${LocationReminderFgService.insideKeyPrefix}${e.key}',
        e.value,
      );
    }

    // 6) 发通知
    if (result.notifications.isNotEmpty) {
      await LocNotificationService().init();
      for (final n in result.notifications) {
        await LocNotificationService().show(
          id: n.reminderId,
          title: n.title,
          body: n.body,
        );
        debugPrint('$_tag 已发通知 id=${n.reminderId} ${n.body}');
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    try {
      await _db?.close();
    } catch (_) {}
    _db = null;
  }

  /// 用户划掉常驻通知（Android 14+ 系统允许划掉 FGS 通知但服务仍在）：
  /// 视为「停止监测」，主动停掉服务并清空状态。
  /// 不停的话服务会以无通知状态继续跑，违反用户意图。
  @override
  Future<void> onNotificationDismissed() async {
    debugPrint('$_tag 常驻通知被划掉，停止服务');
    try {
      await LocationReminderFgService.stop();
    } catch (e) {
      debugPrint('$_tag 响应划掉停止失败: $e');
    }
  }
}
