import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/notifications/app_notifications.dart';
import '../data/geofence_state_store.dart';
import '../domain/geofence_pulse.dart';
import '../domain/location_repository.dart';

/// ============================================================================
/// 途径提醒的前台轮询器（**兜底链路**）
/// ============================================================================
///
/// R4 之后主链路是前台服务（后台也能触发）。这个类只在服务起不来时兜底：
/// 权限被拒、系统限制前台服务、或非 Android 平台。
///
/// 与后台链路共用同一套判定（`runPulse`）和同一份状态缓存
/// （`GeofenceStateStore`）—— 否则两条链路交替工作时「上次在内/在外」
/// 各记各的，用户会收到重复提醒，或者干脆收不到。
class LocationWatcher {
  LocationWatcher(this._repo, {GeofenceStateStore? state})
    : _state = state ?? GeofenceStateStore();

  final LocationRepository _repo;
  final GeofenceStateStore _state;

  final StreamController<LocationAlert> _alerts =
      StreamController<LocationAlert>.broadcast();

  /// 前台监听它弹 SnackBar。
  Stream<LocationAlert> get alerts => _alerts.stream;

  Timer? _timer;
  bool _busy = false;

  /// 最近一次位置（页面显示"当前坐标"用）。
  Position? lastPosition;

  bool get isRunning => _timer != null;

  /// 启动轮询。权限不足时**静默不启动**（页面里另有引导按钮）。
  Future<bool> start({Duration interval = const Duration(seconds: 30)}) async {
    if (_timer != null) return true;
    if (!await _ensureReady()) return false;
    _timer = Timer.periodic(interval, (_) => unawaited(tick()));
    unawaited(tick());
    return true;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stop();
    await _alerts.close();
  }

  /// 权限 + 定位服务是否就绪。
  Future<bool> _ensureReady() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// 取一次位置 → 判定所有围栏。
  ///
  /// 抽成 public：单测/调试可以直接调它，不必等 30 秒。
  Future<void> tick() async {
    if (_busy) return;
    _busy = true;
    try {
      if (!await _ensureReady()) return;
      // 先要"当前"定位；拿不到（室内/无 GPS fix）就退回"最后已知位置"——
      // 否则模拟器/室内场景下永远不触发，用户会以为功能坏了。
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        position = null;
      }
      position ??= await Geolocator.getLastKnownPosition();
      if (position == null) return;
      lastPosition = position;

      final reminders = await _repo.allEnabled();
      if (reminders.isEmpty) return;

      final snapshot = await _state.load();
      final now = DateTime.now();
      final result = runPulse(
        reminders: reminders,
        latitude: position.latitude,
        longitude: position.longitude,
        lastInside: snapshot.inside,
        lastNotified: snapshot.notified,
        now: now,
      );

      await _state.saveInside(result.insideById);

      for (final alert in result.alerts) {
        await _repo.markNotified(alert.reminderId, now);
        await _state.saveNotified(alert.reminderId, now);
        await AppNotifications.show(
          id: AppNotifications.locationIdBase + alert.reminderId,
          title: alert.title,
          body: alert.message,
        );
        if (!_alerts.isClosed) _alerts.add(alert);
      }
    } catch (_) {
      // 定位失败（无 GPS / 超时）不打扰用户：下一拍继续
    } finally {
      _busy = false;
    }
  }

  /// 立刻评估一次（用户点「立即检查」/ 刚加完提醒时用）。
  Future<void> checkNow() => tick();
}
