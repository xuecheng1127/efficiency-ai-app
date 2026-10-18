/// ============================================================================
/// 途径提醒：地理围栏与触发判定（**纯 Dart**）
/// ============================================================================
///
/// 距离用 haversine 公式（够准、无需依赖）：地球平均半径 6371000 m。
/// 判定与"去重（24h）"都放在这里，才能在 `test/` 里脱离定位服务验证。
library;

import 'dart:math' as math;

/// 触发方向。
enum TriggerOn {
  enter(id: 'enter', label: '到达时提醒'),
  exit(id: 'exit', label: '离开时提醒');

  const TriggerOn({required this.id, required this.label});

  final String id;
  final String label;

  static TriggerOn byId(String? id) =>
      id == 'exit' ? TriggerOn.exit : TriggerOn.enter;
}

/// 一条途径提醒（映射 `location_reminders`）。
class LocationReminder {
  const LocationReminder({
    required this.id,
    required this.title,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.triggerOn,
    required this.enabled,
    this.notifiedAt,
    required this.createdAt,
    this.deletedAt,
  });

  final int id;
  final String title;
  final String placeName;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final TriggerOn triggerOn;
  final bool enabled;
  final DateTime? notifiedAt;
  final DateTime createdAt;
  final DateTime? deletedAt;
}

/// 一次触发（给 UI 弹 SnackBar / 发通知用）。
class LocationTrigger {
  const LocationTrigger({required this.reminder, required this.distanceMeters});

  final LocationReminder reminder;
  final double distanceMeters;

  String get message {
    final where = reminder.placeName.isEmpty ? '该地点' : reminder.placeName;
    return reminder.triggerOn == TriggerOn.enter
        ? '你已到达 $where'
        : '你已离开 $where';
  }
}

/// 两点间距离（米）。haversine。
double distanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
}

double _rad(double deg) => deg * math.pi / 180;

/// 是否在围栏内。
bool isInside(LocationReminder r, double lat, double lon) {
  return distanceMeters(r.latitude, r.longitude, lat, lon) <= r.radiusMeters;
}

/// 24 小时内不重复提醒（规格硬要求）。
bool canNotifyNow(LocationReminder r, DateTime now) {
  final last = r.notifiedAt;
  if (last == null) return true;
  return now.difference(last) >= const Duration(hours: 24);
}

/// 判定「这次位置更新是否触发」。
///
/// [lastInside] 是该围栏上一次的"在内/在外"状态（内存里维护）：
/// - enter：上次不在内、这次在内 → 触发；
/// - exit ：上次在内、这次不在内 → 触发；
/// - 首次（null）按"在外"处理 —— 这样 App 打开时你已经在超市里，也会提醒一次。
///
/// 返回 null 表示不触发；[stateAfter] 供调用方更新缓存。
class GeofenceDecision {
  const GeofenceDecision({this.trigger, required this.inside});

  final LocationTrigger? trigger;
  final bool inside;
}

GeofenceDecision evaluate({
  required LocationReminder reminder,
  required double lat,
  required double lon,
  required bool? lastInside,
  required DateTime now,
}) {
  final inside = isInside(reminder, lat, lon);
  final distance = distanceMeters(
    reminder.latitude,
    reminder.longitude,
    lat,
    lon,
  );

  if (!reminder.enabled || reminder.deletedAt != null) {
    return GeofenceDecision(inside: inside);
  }

  final bool crossed;
  switch (reminder.triggerOn) {
    case TriggerOn.enter:
      crossed = !(lastInside ?? false) && inside;
    case TriggerOn.exit:
      crossed = (lastInside ?? false) && !inside;
  }

  if (!crossed || !canNotifyNow(reminder, now)) {
    return GeofenceDecision(inside: inside);
  }

  return GeofenceDecision(
    inside: inside,
    trigger: LocationTrigger(reminder: reminder, distanceMeters: distance),
  );
}
