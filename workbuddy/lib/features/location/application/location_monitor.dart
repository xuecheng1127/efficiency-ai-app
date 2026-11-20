import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/app_paths.dart';
import '../data/geofence_state_store.dart';
import '../domain/geofence_pulse.dart';
import '../domain/location_repository.dart';
import 'location_task_handler.dart';
import 'location_watcher.dart';

/// 一次「顺手对齐」的结果。
///
/// 给 UI 用：保存成功与否只看数据库，这个结果只决定提示里那句
/// 「后台监测已开启 / 仅前台监测」怎么说。
class ServiceNudge {
  const ServiceNudge({required this.ok, this.error});

  final bool ok;
  final String? error;
}

/// ============================================================================
/// 途径提醒的「监测总开关」（主 isolate）
/// ============================================================================
///
/// 职责只有三件，但每一件都有踩过的坑：
///
/// 1. **决定用哪条链路**：
///    有启用中的围栏且用户没暂停 → 起前台服务（后台也能触发）；
///    服务起不来（权限/系统限制）→ 退回老的前台轮询（至少 App 打开时还能用）；
///    一条围栏都没有 → 两条都关（不留常驻通知，也不空转耗电）。
///
/// 2. **两条链路互斥**：服务在跑时**必须**停掉前台 30 秒定时器，
///    否则同一个地点会收到两条通知（一条来自服务、一条来自 App 内定时器）。
///
/// 3. **把后台的「上次提醒」补回数据库**：
///    后台不写库，只在 prefs 里记时间；不补写的话列表上「上次提醒」永远停在
///    App 侧那一次，用户会以为后台根本没工作过。
class LocationMonitor extends ChangeNotifier {
  LocationMonitor(this._repo, this._watcher);

  final LocationRepository _repo;
  final LocationWatcher _watcher;
  final GeofenceStateStore _state = GeofenceStateStore();
  final StreamController<LocationAlert> _alerts =
      StreamController<LocationAlert>.broadcast();

  bool _initialized = false;
  bool _serviceRunning = false;
  bool _userPaused = false;
  int _enabledCount = 0;
  String? _lastError;
  StreamSubscription<LocationAlert>? _watcherSub;

  /// 后台触发 → 前台弹 SnackBar。
  Stream<LocationAlert> get alerts => _alerts.stream;

  bool get serviceRunning => _serviceRunning;
  bool get userPaused => _userPaused;
  int get enabledCount => _enabledCount;
  String? get lastError => _lastError;

  static const int _serviceId = 8410;

  /// 初始化插件（幂等）。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_geofence',
        channelName: '途径提醒常驻',
        channelDescription: '有启用中的地点提醒时显示，告诉你后台正在监测几个地点',
        // LOW：常驻通知不该发出声音/弹窗，它只是「我还在跑」的凭据
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 60 秒是硬指标：再快没有意义（人走路 60 秒才移动一个街区），
        // 再慢会让「路过超市」这种 1-2 分钟的窗口漏掉。
        eventAction: ForegroundTaskEventAction.repeat(60 * 1000),
        // 开机自启 + 更新后自启：后台提醒的价值就在于「用户不用记得打开 App」。
        // 风险（开机阶段库还没解密 → 读不到围栏）由 TaskHandler.onStart 里的
        // 「没有围栏就自停」兜住。
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);

    // 兜底链路的触发也要走同一个出口，前台才能只订阅一处
    _watcherSub = _watcher.alerts.listen((alert) {
      if (!_alerts.isClosed) _alerts.add(alert);
    });
  }

  /// 主 isolate 收到后台回传的数据（只有围栏触发会发）。
  void _onTaskData(Object data) {
    final alert = LocationAlert.tryParse(data);
    if (alert == null) return;
    if (!_alerts.isClosed) _alerts.add(alert);
  }

  /// 与「启用中的围栏」对齐一次。调用时机：
  /// App 启动 / 提醒增删改 / 回到前台 / 用户点「开启」。
  ///
  /// **整段串行执行**：实测「保存提醒」这一下会同时触发两路 sync
  /// （编辑页的 `resumeByUserAction` + 根部监听收到列表变化），
  /// 并发时后到的 `startService` 会撞 `ServiceAlreadyStartedException`、
  /// 把 `_serviceRunning` 误判成 false，界面就显示「仅前台监测」——
  /// 而 `dumpsys` 里服务明明在跑（前台类型 0x8 = location）。
  ///
  /// 注意：`sync()` 会把异常抛给调用方（根部监听自己吞）。
  /// 页面里的保存/开关请用 [nudge]：它带超时且绝不上抛。
  Future<void> sync() => _guard(_syncImpl);

  /// 带超时的「顺手对齐」：最多等 [timeout]，失败只记日志。
  ///
  /// R4B 新增：保存提醒**不能**被后台服务的启动成败卡住。
  /// v1.6 的实际故障就是这里 —— 点保存后 `sync()` 上抛，
  /// 而 `_save()` 没有 finally 复位 `_saving`，按钮永久停在「保存中…」
  /// （数据其实早就写进库了，用户却以为没存上）。
  Future<ServiceNudge> nudge({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await sync().timeout(timeout);
      return ServiceNudge(ok: _serviceRunning, error: _lastError);
    } on TimeoutException {
      _lastError = '后台监测启动超时（${timeout.inSeconds}s）';
      debugPrint('[geofence] nudge timeout: ${timeout.inSeconds}s');
      return ServiceNudge(ok: false, error: _lastError);
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[geofence] nudge failed: $e');
      return ServiceNudge(ok: false, error: _lastError);
    } finally {
      notifyListeners();
    }
  }

  Future<void> _syncImpl() async {
    await init();

    final path = await AppPaths.dbPath();
    if (path != null) AppPaths.rememberDbPath(path);

    final reminders = await _repo.allEnabled();
    _enabledCount = reminders.length;
    _userPaused = await _state.isPaused();

    // 后台记的时间补回数据库（只在这一侧写库）
    await _flushNotifiedToDb();

    if (_enabledCount == 0) {
      await _stopService();
      _watcher.stop();
      notifyListeners();
      return;
    }

    if (_userPaused) {
      // 用户划掉过常驻通知：不自动拉起服务，退回前台轮询，
      // 至少「App 打开时」这个功能还是活的。
      await _stopService();
      await _watcher.start();
      notifyListeners();
      return;
    }

    final started = await _startService(_enabledCount);
    if (started) {
      // 服务接管后必须停掉 App 内的定时器，否则同一地点双份通知
      _watcher.stop();
    } else {
      await _watcher.start();
    }
    notifyListeners();
  }

  /// 串行闸门：所有会碰服务的操作都从这里过，同一时刻只有一个在跑。
  ///
  /// **旧实现的致命 bug（R4B 修）**：它把 `action()` 的结果直接接在 `_serial` 上，
  /// 一次抛错就让 `_serial` 永久变成 error 状态的 future ——
  /// 之后每一次 `then` 都跳过回调、直接把同一个错误抛回去，
  /// 于是 `sync()` 再也不执行，界面上「后台监测」永远起不来。
  /// 现在：`_serial` 只接受已消化异常的 future，调用方拿到的仍是本次结果。
  Future<void> _serial = Future<void>.value();

  Future<void> _guard(Future<void> Function() action) {
    final next = _serial.then((_) => action(), onError: (_) => action());
    _serial = next.then<void>(
      (_) {},
      onError: (Object e) => debugPrint('[geofence] sync failed: $e'),
    );
    return next;
  }

  /// 用户主动改了提醒（新增 / 打开开关 / 点「开启」按钮）→ 解除暂停并重新同步。
  ///
  /// **不上抛**：调用点都是 UI 按钮，异常不能变成「点了没反应」。
  Future<ServiceNudge> resumeByUserAction() async {
    await _state.setPaused(false);
    _userPaused = false;
    return nudge();
  }

  /// 立刻停服务（页面「关闭后台监测」用）。
  Future<void> stopService() async {
    await _guard(_stopService);
    notifyListeners();
  }

  Future<bool> _startService(int count) async {
    final text = '$count 个地点正在监测';
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: '途径提醒运行中',
          notificationText: text,
        );
        _serviceRunning = true;
        _lastError = null;
        return true;
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: '途径提醒运行中',
        notificationText: text,
        callback: locationReminderCallback,
      );
      if (result is ServiceRequestSuccess) {
        _serviceRunning = true;
        _lastError = null;
        return true;
      }
      // 竞态兜底：服务刚起的前 5 秒里插件会报 ServiceAlreadyStartedException，
      // 但服务其实是在跑的 —— 一切以 isRunningService 为准。
      if (await FlutterForegroundTask.isRunningService) {
        _serviceRunning = true;
        _lastError = null;
        return true;
      }
      _serviceRunning = false;
      _lastError = (result as ServiceRequestFailure).error.toString();
      return false;
    } catch (e) {
      if (await FlutterForegroundTask.isRunningService) {
        _serviceRunning = true;
        _lastError = null;
        return true;
      }
      _serviceRunning = false;
      _lastError = e.toString();
      return false;
    }
  }

  Future<void> _stopService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
    _serviceRunning = false;
  }

  /// 缓存里更新的「上次提醒」写回数据库。
  Future<void> _flushNotifiedToDb() async {
    try {
      final snapshot = await _state.load();
      if (snapshot.notified.isEmpty) return;
      final reminders = await _repo.allEnabled();
      for (final r in reminders) {
        final cached = snapshot.notified[r.id];
        if (cached == null) continue;
        if (r.notifiedAt != null && !cached.isAfter(r.notifiedAt!)) continue;
        await _repo.markNotified(r.id, cached);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _watcherSub?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _alerts.close();
    super.dispose();
  }
}
