import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/notifications/app_notifications.dart';
import '../data/geofence_state_store.dart';
import '../data/reminder_snapshot.dart';
import '../domain/geofence_pulse.dart';

/// ============================================================================
/// 前台服务的后台任务：**App 被杀掉也照样盯着地点**
/// ============================================================================
///
/// 这是 R4 的核心。之前的实现只有「App 在前台时的 30 秒定时器」——
/// 用户走路时手机在口袋里、App 在后台，那个定时器会被系统挂起，
/// 于是「走到超市附近提醒我」等于没做。
///
/// 现在这条链路是：
///   前台服务（location 类型）→ 每 60 秒 onRepeatEvent →
///   取位置（先 last known，必要时 current）→ 直读 SQLite 拿启用中的围栏 →
///   纯函数判定（`runPulse`）→ 状态翻转才发通知 → 状态写 JSON 文件（见 GeofenceStateStore）。
///
/// 三条纪律：
/// 1. **不做写库**：后台只 SELECT（见 `ReminderSnapshot` 顶部说明）；
/// 2. **不并发**：`onRepeatEvent` 是 60 秒一跳，但一次定位可能超时更久，
///    用 `_busy` 拦住重入，否则会累积一串并发的 getCurrentPosition；
/// 3. **拿不到位置就安静地等下一拍**：绝不弹「定位失败」打扰用户。

/// 服务回调入口。**必须是顶层函数并带 `vm:entry-point`**，
/// 否则 release 包 tree-shaking 会把它删掉（后台 isolate 直接起不来）。
@pragma('vm:entry-point')
void locationReminderCallback() {
  FlutterForegroundTask.setTaskHandler(LocationReminderTaskHandler());
}

class LocationReminderTaskHandler extends TaskHandler {
  LocationReminderTaskHandler({
    ReminderSnapshot? snapshot,
    GeofenceStateStore? state,
  }) : _snapshot = snapshot ?? const ReminderSnapshot(),
       _state = state ?? GeofenceStateStore();

  final ReminderSnapshot _snapshot;
  final GeofenceStateStore _state;

  bool _busy = false;

  /// 用户划掉常驻通知 / 没有启用中的提醒 → 停掉本轮循环。
  bool _stopped = false;

  /// 上一次成功拿到位置的时间（只为日志与节流判断）。
  DateTime? _lastFixAt;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 顺序不能反：先有 binding，再登记插件实现。
    //
    // R4B 修的坑：v1.6 里这两步都被 `catch (_) {}` 吞掉，于是「插件没接上」
    // 完全没有痕迹 —— 表现是 `[geofence] prefs unavailable` 之后这一拍静默失败。
    // 现在照样不致命（定位/通知失败按「这一拍没数据」处理），但要留下日志。
    try {
      WidgetsFlutterBinding.ensureInitialized();
    } catch (e) {
      debugPrint('[geofence] binding init failed: $e');
    }
    try {
      DartPluginRegistrant.ensureInitialized();
      debugPrint('[geofence] plugins registered for task isolate');
    } catch (e) {
      debugPrint('[geofence] plugin registrant failed: $e');
    }

    await AppNotifications.init();

    if (starter == TaskStarter.system) {
      // 开机自启：插件会把上一次的常驻通知恢复出来，此时必须核对现实 ——
      // 没围栏 / 用户已暂停，就立刻收摊，不留一条「0 个地点正在监测」的假通知。
      final state = await _state.load();
      final reminders = await _snapshot.readEnabled();
      if (state.paused || (reminders != null && reminders.isEmpty)) {
        await _stopSelf();
      }
    }
    debugPrint('[geofence] task started (${starter.name})');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_pulse());
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[geofence] task destroyed');
    _stopped = true;
  }

  @override
  void onNotificationDismissed() {
    // 常驻通知被划掉 = 用户明确要求停止。落盘暂停标记，
    // 这样下次进 App 也不会被「自动拉起服务」偷袭。
    debugPrint('[geofence] notification dismissed → stop');
    _stopped = true;
    unawaited(_state.setPaused(true));
    unawaited(_stopSelf());
  }

  Future<void> _pulse() async {
    if (_busy || _stopped) return;
    _busy = true;
    try {
      final reminders = await _snapshot.readEnabled();
      if (reminders == null) {
        // 读库失败 ≠ 没有围栏：绝不能因此把服务停掉（那等于自废武功）
        debugPrint('[geofence] pulse skipped: reminders unreadable');
        return;
      }
      if (reminders.isEmpty) {
        debugPrint('[geofence] pulse: no enabled reminders → stop service');
        await _stopSelf();
        return;
      }

      final position = await _currentPosition();
      if (position == null) {
        debugPrint('[geofence] pulse: no position');
        return;
      }
      _lastFixAt = DateTime.now();

      final state = await _state.load();
      final now = DateTime.now();
      final result = runPulse(
        reminders: reminders,
        latitude: position.latitude,
        longitude: position.longitude,
        lastInside: state.inside,
        lastNotified: state.notified,
        now: now,
      );

      // 即使没有触发也要写回「在内/在外」，否则离开模式永远等不到翻转。
      await _state.saveInside(result.insideById);
      await _state.saveLastPulse(now);

      debugPrint(
        '[geofence] pulse ok: ${reminders.length} fence(s), '
        'at ${position.latitude.toStringAsFixed(5)},'
        '${position.longitude.toStringAsFixed(5)}, '
        'inside=${result.insideById}, alerts=${result.alerts.length}',
      );

      for (final alert in result.alerts) {
        await _state.saveNotified(alert.reminderId, now);
        await AppNotifications.show(
          id: AppNotifications.locationIdBase + alert.reminderId,
          title: alert.title,
          body: alert.message,
        );
        debugPrint('[geofence] notified #${alert.reminderId}: ${alert.message}');
        // App 若在前台，主 isolate 会收到并再弹一次 SnackBar。
        FlutterForegroundTask.sendDataToMain(alert.toJson());
      }
    } catch (e) {
      // 后台任务里任何异常都不该让 60 秒的循环停掉
      debugPrint('[geofence] pulse error: $e');
    } finally {
      _busy = false;
    }
  }

  /// 取一次位置：先要「上次已知」（零成本），太旧才真的去定位。
  ///
  /// 精度策略（R4B 调整）：**先省钱，拿不到再加钱**。
  /// 1. `low`（≈ 城市级 / 基站级，`PRIORITY_LOW_POWER`）：围栏半径 ≥100 米，
  ///    这一档够用，而且不会让 GPS 芯片常开 —— 这是本功能最容易被骂的耗电点；
  /// 2. `low` 超时（室内、飞行模式、emulator 无网络定位）→ 再用 `high` 试一次：
  ///    只升级这一次、每秒只跑一拍，失败就安静地等下一拍。
  ///
  /// 为什么必须加第 2 档：`PRIORITY_LOW_POWER` 在只有 GPS、没有网络定位的
  /// 设备上**永远拿不到 fix**（实测 emulator：`TimeoutException after 20s`），
  /// 于是「走到超市」永远不会触发 —— 只是安静地不工作，比报错更难发现。
  Future<Position?> _currentPosition() async {
    final lastKnown = await _lastKnown();
    if (lastKnown != null &&
        DateTime.now().difference(lastKnown.timestamp) <
            const Duration(minutes: 3)) {
      return lastKnown;
    }

    final cheap = await _fix(LocationAccuracy.low, const Duration(seconds: 20));
    if (cheap != null) return cheap;

    final precise = await _fix(
      LocationAccuracy.high,
      const Duration(seconds: 15),
    );
    if (precise != null) return precise;

    // 超时/无 fix：退回「上次已知」也好过没有
    return lastKnown;
  }

  Future<Position?> _fix(LocationAccuracy accuracy, Duration timeLimit) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
    } catch (e) {
      debugPrint('[geofence] ${accuracy.name} fix failed: $e');
      return null;
    }
  }

  Future<Position?> _lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('[geofence] last known failed: $e');
      return null;
    }
  }

  Future<void> _stopSelf() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // 服务已经不在（或通道不可用）：无需处理
    }
  }

  /// 最近一次定位时间（调试/测试观察用）。
  DateTime? get lastFixAt => _lastFixAt;
}
