library;

import 'dart:math';

/// 途径提醒后台触发的纯函数引擎（R4）
///
/// 全部为无副作用纯函数：不依赖 Flutter、不依赖数据库、不依赖插件，
/// 输入数据 + 当前坐标 + 历史状态，输出本次应发的通知与更新后的状态。
/// 供前台服务 TaskHandler（后台 isolate）与单元测试共同使用。

/// 一条途径提醒的判定输入（由调用方从数据库行映射而来）
class GeoReminderInput {
  final int id;
  final String title;
  final String placeName;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  /// 'enter' 进入时提醒 / 'exit' 离开时提醒
  final String triggerOn;

  const GeoReminderInput({
    required this.id,
    required this.title,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.triggerOn = 'enter',
  });
}

/// 一次轮询的输入
class GeoCheckInput {
  final double latitude;
  final double longitude;
  final List<GeoReminderInput> reminders;

  /// 上次状态：reminderId -> 是否在半径内（true=inside）
  final Map<int, bool> lastInside;

  const GeoCheckInput({
    required this.latitude,
    required this.longitude,
    required this.reminders,
    this.lastInside = const {},
  });
}

/// 一次判定产生的通知（不含通知渠道逻辑）
class GeoNotification {
  final int reminderId;
  final String title;
  final String body;

  /// 'enter' 或 'exit'
  final String kind;

  const GeoNotification({
    required this.reminderId,
    required this.title,
    required this.body,
    required this.kind,
  });
}

/// 一次轮询的输出
class GeoCheckResult {
  /// 需要发送的通知（可能为空）
  final List<GeoNotification> notifications;

  /// 更新后的 inside 状态（含未被触发但状态已明确的提醒）
  final Map<int, bool> insideStates;

  const GeoCheckResult({
    required this.notifications,
    required this.insideStates,
  });
}

/// Haversine 球面距离（米）
double geoDistanceMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const r = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = _sin2(dLat / 2) +
      _cos(lat1) * _cos(lat2) * _sin2(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return r * c;
}

/// 单条提醒 + 当前位置 → 是否在半径内
bool isInside(GeoReminderInput r, double lat, double lng) {
  if (r.radiusMeters <= 0) return false;
  return geoDistanceMeters(lat, lng, r.latitude, r.longitude) <=
      r.radiusMeters;
}

/// 核心状态机：一次轮询判定
///
/// 规则：
/// - 首次见到该提醒（lastInside 无记录）：
///   - 已在半径内：enter 类发「进入」通知（用户刚加完提醒就在地点里，值得提醒）；
///     exit 类不发（否则一启用就吵），仅记录状态等待离开。
///   - 不在半径内：不发通知，仅记录 outside。
/// - 状态翻转时才通知：outside→inside 且 enter 类 → 进入通知；
///   inside→outside 且 exit 类 → 离开通知。
/// - 触发模式不匹配的翻转只更新状态、不通知。
GeoCheckResult evaluateGeoCheck(GeoCheckInput input) {
  final notifications = <GeoNotification>[];
  final insideStates = <int, bool>{};

  for (final r in input.reminders) {
    final nowInside = isInside(r, input.latitude, input.longitude);
    final lastInside = input.lastInside[r.id];

    if (lastInside == null) {
      // 首次采样
      if (nowInside && r.triggerOn == 'enter') {
        notifications.add(GeoNotification(
          reminderId: r.id,
          title: '途径提醒',
          body: '到达【${r.placeName}】附近 —— ${r.title}',
          kind: 'enter',
        ));
      }
    } else if (lastInside != nowInside) {
      // 状态翻转
      if (nowInside && r.triggerOn == 'enter') {
        notifications.add(GeoNotification(
          reminderId: r.id,
          title: '途径提醒',
          body: '到达【${r.placeName}】附近 —— ${r.title}',
          kind: 'enter',
        ));
      } else if (!nowInside && r.triggerOn == 'exit') {
        notifications.add(GeoNotification(
          reminderId: r.id,
          title: '途径提醒',
          body: '已离开【${r.placeName}】 —— ${r.title}',
          kind: 'exit',
        ));
      }
    }

    insideStates[r.id] = nowInside;
  }

  return GeoCheckResult(
    notifications: notifications,
    insideStates: insideStates,
  );
}

/// 服务通知文案：监测中的地点数
String serviceNotificationText(int count) {
  return '$count 个地点正在监测';
}

double _toRad(double deg) => deg * pi / 180.0;
double _sin2(double x) => sin(x) * sin(x);
double _cos(double deg) => cos(_toRad(deg));
