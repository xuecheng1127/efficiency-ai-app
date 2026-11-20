/// ============================================================================
/// 一次「定位采样」对全部围栏的判定（**纯 Dart，无 I/O**）
/// ============================================================================
///
/// 前台的 `LocationWatcher` 与后台的前台服务（`LocationReminderTaskHandler`）
/// 走的是同一段判定：位置 → 每条围栏 → 是否翻转 → 是否该发通知。
///
/// 之所以抽成纯函数：
/// - 后台 isolate 里没有任何 Riverpod / Drift 运行时，判定逻辑必须能脱离它们；
/// - 「上次在内/在外」和「上次提醒时间」在后台记在 JSON 状态文件，
///   前台记在内存 + 数据库，两个来源都要能喂进来做单测。
library;

import 'location_reminder.dart';

/// 一条要弹给用户的提醒（跨 isolate 传输的载体）。
///
/// 后台 isolate 发完通知后，把它 `sendDataToMain` 回主 isolate，
/// 前台再弹一次 SnackBar —— 所以它必须能无损地塞进 `SendPort`（纯 Map）。
class LocationAlert {
  const LocationAlert({
    required this.reminderId,
    required this.title,
    required this.placeName,
    required this.message,
    required this.distanceMeters,
  });

  final int reminderId;
  final String title;
  final String placeName;
  final String message;
  final double distanceMeters;

  Map<String, Object?> toJson() => {
    'kind': 'geofence',
    'id': reminderId,
    'title': title,
    'place': placeName,
    'message': message,
    'distance': distanceMeters,
  };

  /// 解析后台传回来的数据；不是围栏提醒就返回 null（将来别的任务也走这条通道）。
  static LocationAlert? tryParse(Object? data) {
    if (data is! Map) return null;
    if (data['kind'] != 'geofence') return null;
    final id = data['id'];
    if (id is! int) return null;
    return LocationAlert(
      reminderId: id,
      title: (data['title'] as String?) ?? '地点提醒',
      placeName: (data['place'] as String?) ?? '',
      message: (data['message'] as String?) ?? '你已到达该地点',
      distanceMeters: (data['distance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 一次采样的完整结果。
class PulseResult {
  const PulseResult({
    required this.alerts,
    required this.insideById,
  });

  /// 本次需要发的通知（已按「状态翻转 + 24h 去重」过滤）。
  final List<LocationAlert> alerts;

  /// 每条围栏的最新「在内/在外」—— 无论是否触发都要写回，
  /// 否则「离开」永远等不到「上次在内」。
  final Map<int, bool> insideById;

  bool get isEmpty => alerts.isEmpty;
}

/// 取两个「上次提醒时间」里更晚的那个（数据库与本地缓存可能各有一份）。
DateTime? latestOf(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// 跑一次采样。
///
/// [lastNotified] 是本地缓存（后台 isolate 唯一能写的地方），
/// 与实体自带的 `notifiedAt`（数据库）取更晚者 —— 两条路径交替触发时
/// 24 小时去重才不会因为「换了写入方」而失效。
PulseResult runPulse({
  required List<LocationReminder> reminders,
  required double latitude,
  required double longitude,
  required Map<int, bool> lastInside,
  required Map<int, DateTime> lastNotified,
  required DateTime now,
}) {
  final inside = <int, bool>{};
  final alerts = <LocationAlert>[];

  for (final r in reminders) {
    final last = latestOf(r.notifiedAt, lastNotified[r.id]);
    final decision = evaluate(
      reminder: r.withNotifiedAt(last),
      lat: latitude,
      lon: longitude,
      lastInside: lastInside[r.id],
      now: now,
    );
    inside[r.id] = decision.inside;

    final trigger = decision.trigger;
    if (trigger == null) continue;
    alerts.add(
      LocationAlert(
        reminderId: r.id,
        title: r.title,
        placeName: r.placeName,
        message: trigger.message,
        distanceMeters: trigger.distanceMeters,
      ),
    );
  }

  return PulseResult(alerts: alerts, insideById: inside);
}
