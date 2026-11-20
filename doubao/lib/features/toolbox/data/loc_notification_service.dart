import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocNotificationService {
  static final LocNotificationService _instance = LocNotificationService._();
  factory LocNotificationService() => _instance;
  LocNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    const channel = AndroidNotificationChannel(
      'location_reminder',
      '途径提醒',
      description: '走到附近时的提醒通知',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    // requestNotificationsPermission 需要前台 Activity，在后台 isolate 调用
    // 会因 mainActivity == null 抛 NPE（插件源码 L1924 用 mainActivity 做权限
    // 检查）。权限由前台 UI 申请，这里只做展示（渠道已建）。
    _initialized = true;
  }

  /// 前台申请通知权限（只能在有 Activity 的前台调用）
  ///
  /// 后台 TaskHandler 不允许调 requestNotificationsPermission：
  /// 插件原生层用 mainActivity 做权限检查（L1924），后台 isolate
  /// 的引擎没有 Activity，会抛 NullPointerException。
  Future<void> requestPermissionFromForeground() async {
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'location_reminder',
        '途径提醒',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
