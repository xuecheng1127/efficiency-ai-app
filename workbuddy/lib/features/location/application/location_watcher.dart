import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/notifications/app_notifications.dart';
import '../domain/location_reminder.dart';
import '../domain/location_repository.dart';

/// ============================================================================
/// 途径提醒的前台轮询器
/// ============================================================================
///
/// 规格实现路径：**先前台轮询（30 秒）**，后续再上前台服务。
/// 所以这里刻意用 `Timer.periodic`，不申请后台定位 ——
/// App 在后台时 Dart 定时器会被系统挂起，本来也不会偷偷耗电。
///
/// 三件事：
/// 1. 每 30 秒取一次当前位置（中等精度，省电，200m 半径够用）；
/// 2. 对每条提醒做进入/离开判定 + 24 小时去重（逻辑在 domain，可单测）；
/// 3. 触发时：发本地通知 + 往 [triggers] 里推一条（前台用 SnackBar 再提示一次）。
class LocationWatcher {
  LocationWatcher(this._repo);

  final LocationRepository _repo;

  final StreamController<LocationTrigger> _triggers =
      StreamController<LocationTrigger>.broadcast();

  /// 前台监听它弹 SnackBar。
  Stream<LocationTrigger> get triggers => _triggers.stream;

  Timer? _timer;
  bool _busy = false;

  /// 每个围栏上一次是否在内（内存态；重启后按"在外"处理）。
  final Map<int, bool> _lastInside = {};

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
    await _triggers.close();
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
      final now = DateTime.now();
      for (final r in reminders) {
        final decision = evaluate(
          reminder: r,
          lat: position.latitude,
          lon: position.longitude,
          lastInside: _lastInside[r.id],
          now: now,
        );
        _lastInside[r.id] = decision.inside;

        final trigger = decision.trigger;
        if (trigger == null) continue;

        await _repo.markNotified(r.id, now);
        await AppNotifications.show(
          id: AppNotifications.locationIdBase + r.id,
          title: r.title,
          body: trigger.message,
        );
        if (!_triggers.isClosed) _triggers.add(trigger);
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
