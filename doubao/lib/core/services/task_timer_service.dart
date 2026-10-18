import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 任务后台计时前台服务（模块1 P0 计时器）
///
/// 职责：
/// - 封装 flutter_foreground_task（8.x）前台服务：初始化、启动/停止、通知栏常驻；
/// - 通知栏带「暂停 / 完成」按钮，按钮点击由后台 TaskHandler 转发回主 isolate；
/// - 每秒心跳（onRepeatEvent）刷新通知栏文本，展示累计耗时；
/// - 主 isolate 通过数据回调接收按钮事件与心跳，供 Riverpod 层驱动 UI。
///
/// 设计说明：
/// - 前台服务进程与 App 同进程，但 startService 后系统会提升进程优先级，
///   Android 上退出 App / 锁屏期间计时不中断（stopWithTask=false）。
/// - 计时基准存于插件内置存储（saveData/getData），后台 isolate 无法访问
///   SharedPreferences 实例，必须用插件提供的跨 isolate 存储。
class TaskTimerService {
  TaskTimerService._();

  static final TaskTimerService instance = TaskTimerService._();

  /// 前台服务唯一 ID（自定义正整数，避免与默认值冲突）
  static const int _serviceId = 256;

  /// 通知渠道 ID
  static const String channelId = 'task_timer_service';

  // ---- 跨 isolate 存储键（TaskHandler 与主 isolate 共享）----

  /// 计时开始时间（epoch millis）
  static const String keyStartedAt = 'timer_started_at';

  /// 本次计时开始前已累计的秒数（数据库 durationSeconds）
  static const String keyBaseSeconds = 'timer_base_seconds';

  /// 当前计时任务标题（通知栏展示）
  static const String keyTitle = 'timer_title';

  /// 当前计时任务 occurrenceId
  static const String keyOccurrenceId = 'timer_occurrence_id';

  /// 通知按钮 ID
  static const String buttonPause = 'pause';
  static const String buttonComplete = 'complete';

  /// 是否已完成一次 init（幂等）
  bool _initialized = false;

  /// 数据回调（主 isolate 侧注册，由 TaskTimerNotifier 持有）
  final List<ValueChanged<Object?>> _dataListeners = [];

  // ==================== 初始化 ====================

  /// 初始化前台服务配置（应用启动时调用一次，幂等）
  ///
  /// 同时把 [dispatch] 注册为插件全局数据回调：
  /// TaskHandler（后台 isolate）发来的数据统一汇聚到这里再分发。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: channelId,
        channelName: '任务计时',
        channelDescription: '任务进入「进行中」后，此通知常驻展示计时状态',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 每秒心跳，刷新通知栏文本（计时显示精度 1s）
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // 注册插件全局数据回调（TaskHandler → 主 isolate）
    FlutterForegroundTask.addTaskDataCallback(dispatch);
  }

  // ==================== 启动 / 停止 ====================

  /// 启动计时前台服务
  ///
  /// [occurrenceId] 当前计时任务实例 id；
  /// [title] 任务标题；
  /// [startedAt] 计时起点；
  /// [baseSeconds] 本次计时开始前已累计秒数（用于跨次累计）。
  Future<void> start({
    required int occurrenceId,
    required String title,
    required DateTime startedAt,
    required int baseSeconds,
  }) async {
    // 写入跨 isolate 存储，TaskHandler 心跳据此计算耗时
    await FlutterForegroundTask.saveData(key: keyStartedAt, value: startedAt.millisecondsSinceEpoch);
    await FlutterForegroundTask.saveData(key: keyBaseSeconds, value: baseSeconds);
    await FlutterForegroundTask.saveData(key: keyTitle, value: title);
    await FlutterForegroundTask.saveData(key: keyOccurrenceId, value: occurrenceId);

    if (await FlutterForegroundTask.isRunningService) {
      // 服务已在运行：重启以触发 onStart 重新读取新任务的计时基准，
      // 通知内容由 onStart/onRepeatEvent 内 updateService 刷新
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: '任务计时中',
        notificationText: title,
        notificationIcon: null,
        notificationButtons: const [
          NotificationButton(id: buttonPause, text: '暂停'),
          NotificationButton(id: buttonComplete, text: '完成'),
        ],
        notificationInitialRoute: '/',
        callback: _serviceCallback,
      );
    }
  }

  /// 更新通知栏计时文本（TaskHandler 心跳调用）
  Future<void> updateNotificationText(String text) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: '任务计时中',
      notificationText: text,
    );
  }

  /// 停止前台服务
  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    // 清理跨 isolate 存储，避免下次误读
    await FlutterForegroundTask.removeData(key: keyStartedAt);
    await FlutterForegroundTask.removeData(key: keyBaseSeconds);
    await FlutterForegroundTask.removeData(key: keyTitle);
    await FlutterForegroundTask.removeData(key: keyOccurrenceId);
  }

  /// 当前前台服务是否在运行
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  // ==================== 权限（场景化申请） ====================

  /// 是否已授予通知权限（Android 13+ 前台服务通知必需）
  Future<bool> hasNotificationPermission() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    return permission == NotificationPermission.granted;
  }

  /// 请求通知权限，返回是否最终授予（首次开始计时时场景化调用）
  Future<bool> requestNotificationPermission() async {
    final permission = await FlutterForegroundTask.requestNotificationPermission();
    return permission == NotificationPermission.granted;
  }

  /// 是否已豁免电池优化（保活增强，可选）
  Future<bool> isIgnoringBatteryOptimizations() {
    return FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  // ==================== 主 isolate 数据回调 ====================

  /// 注册数据回调（TaskHandler → 主 isolate）
  void addDataListener(ValueChanged<Object?> listener) {
    _dataListeners.add(listener);
  }

  /// 移除数据回调（页面销毁时调用，避免泄漏）
  void removeDataListener(ValueChanged<Object?> listener) {
    _dataListeners.remove(listener);
  }

  /// 全局数据分发入口：
  /// 由插件 addTaskDataCallback 注册，TaskHandler 发来的数据分发到各监听器。
  @visibleForTesting
  void dispatch(Object? data) {
    for (final l in _dataListeners) {
      try {
        l(data);
      } catch (e, st) {
        debugPrint('TaskTimerService 数据回调异常: $e\n$st');
      }
    }
  }

  /// 前台服务回调（顶层函数，供 FlutterForegroundTask 后台 isolate 注册）
  ///
  /// @pragma('vm:entry-point')：告知 AOT 编译器该符号必须保留，
  /// 否则 release 构建会被 tree-shaking 移除，导致服务无法启动。
  @pragma('vm:entry-point')
  static void _serviceCallback() {
    FlutterForegroundTask.setTaskHandler(_TimerTaskHandler());
  }
}

/// 后台计时 TaskHandler（运行在 flutter_foreground_task 的后台 isolate）
///
/// 职责：
/// - onStart：启动时读取计时基准；
/// - onRepeatEvent：每秒计算累计耗时并刷新通知栏文本，同时向主 isolate
///   发送心跳数据（供 UI 实时刷新）；
/// - onNotificationButtonPressed：把「暂停 / 完成」事件发送回主 isolate。
class _TimerTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final title = await FlutterForegroundTask.getData<String>(
      key: TaskTimerService.keyTitle,
    );
    final base = await FlutterForegroundTask.getData<int>(
      key: TaskTimerService.keyBaseSeconds,
    );
    final started = await FlutterForegroundTask.getData<int>(
      key: TaskTimerService.keyStartedAt,
    );

    final elapsed = _computeElapsed(
      startedAtMillis: started,
      baseSeconds: base ?? 0,
      now: timestamp,
    );
    await FlutterForegroundTask.updateService(
      notificationTitle: '任务计时中',
      notificationText: title != null && title.isNotEmpty
          ? '$title · ${_format(elapsed)}'
          : _format(elapsed),
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    final started = await FlutterForegroundTask.getData<int>(
      key: TaskTimerService.keyStartedAt,
    );
    final base = await FlutterForegroundTask.getData<int>(
      key: TaskTimerService.keyBaseSeconds,
    );
    final title = await FlutterForegroundTask.getData<String>(
      key: TaskTimerService.keyTitle,
    );

    final elapsed = _computeElapsed(
      startedAtMillis: started,
      baseSeconds: base ?? 0,
      now: timestamp,
    );
    await FlutterForegroundTask.updateService(
      notificationTitle: '任务计时中',
      notificationText: title != null && title.isNotEmpty
          ? '$title · ${_format(elapsed)}'
          : _format(elapsed),
    );

    // 心跳转发主 isolate：通知栏文本已是最新，主 isolate 可据此保持 UI 同步
    FlutterForegroundTask.sendDataToMain({
      'type': 'tick',
      'elapsedSeconds': elapsed,
    });
  }

  @override
  void onNotificationButtonPressed(String id) {
    // 把按钮事件转发回主 isolate，由应用层完成数据库写入与状态流转
    FlutterForegroundTask.sendDataToMain({
      'type': 'button',
      'action': id,
    });
  }

  @override
  void onNotificationPressed() {
    // 点击通知本体：默认拉起 App，无需额外处理
  }

  @override
  void onNotificationDismissed() {
    // 通知被划走：保持服务运行，不响应
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool appKilled) async {
    // 服务销毁时清理监听（由插件管理，无需手动处理）
  }

  /// 计算累计耗时：baseSeconds + (now - startedAt)
  int _computeElapsed({
    required int? startedAtMillis,
    required int baseSeconds,
    required DateTime now,
  }) {
    if (startedAtMillis == null) return baseSeconds;
    final started = DateTime.fromMillisecondsSinceEpoch(startedAtMillis);
    final delta = now.difference(started).inSeconds;
    return baseSeconds + (delta > 0 ? delta : 0);
  }

  String _format(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
