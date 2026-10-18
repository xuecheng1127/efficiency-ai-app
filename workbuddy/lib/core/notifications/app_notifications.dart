import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// ============================================================================
/// 本地通知（工具箱插件共用）
/// ============================================================================
///
/// 谁在用：朋友生日（提前 N 天 09:00）、途径提醒（进入/离开地点）。
///
/// 设计要点：
/// - **单例 + 幂等 init**：`init()` 可被任意入口重复调用，只真正初始化一次；
/// - **不硬编码时区**：`zonedSchedule` 只认 `TZDateTime`，但只要传的是**绝对时刻**
///   （`millisecondsSinceEpoch`）就不会因时区名不同而漂移，因此这里用 UTC 构造。
/// - 失败**不抛给 UI**：通知权限没给 / 渠道创建失败时，功能降级为「只写数据」，
///   绝不因为通知失败把页面搞崩。
class AppNotifications {
  AppNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// 通道 id 固定 —— 改了等于换通道，用户之前的"静音"设置会丢。
  static const String channelId = 'plugin_reminders';
  static const String channelName = '插件提醒';

  /// 通知 id 分段：生日 7xxxx，地点 8xxxx（互不覆盖）。
  static const int birthdayIdBase = 70000;
  static const int locationIdBase = 80000;

  static NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: '生日提醒与途径提醒',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    ),
  );

  static Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: '生日提醒与途径提醒',
          importance: Importance.high,
        ),
      );
      _initialized = true;
    } catch (_) {
      // 通知不可用时静默降级（数据照常写入）
    }
  }

  /// 场景化申请 Android 13+ 的通知权限。
  ///
  /// **不在启动时申请**：一进 App 就弹权限框是最打扰的做法，而且用户还没有
  /// "我需要提醒"的上下文。调用点 = 用户第一次真正创建提醒时（保存生日 / 保存地点）。
  /// 拒绝也不阻断功能：数据照存，只是收不到通知。
  static Future<bool> ensurePermission() async {
    await init();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  /// 立即发一条（途径提醒在前台时用）。
  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(),
      );
    } catch (_) {}
  }

  /// 定时发（生日提醒用）。
  ///
  /// `androidScheduleMode: inexactAllowWhileIdle`：不申请精确闹钟权限也能发，
  /// 系统可能延后几分钟 —— 对"提前 3 天提醒生日"完全够用，且不增加权限门槛。
  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await init();
    if (!when.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.UTC,
          when.millisecondsSinceEpoch,
        ),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    await init();
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }
}
