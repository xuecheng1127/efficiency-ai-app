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
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
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
