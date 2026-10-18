import 'location_reminder.dart';

/// 途径提醒仓库。
abstract interface class LocationRepository {
  Stream<List<LocationReminder>> watchAll();

  /// 只取启用且未删除的（轮询时用）。
  Future<List<LocationReminder>> allEnabled();

  Future<int?> create({
    required String title,
    required String placeName,
    required double latitude,
    required double longitude,
    int radiusMeters = 200,
    TriggerOn triggerOn = TriggerOn.enter,
    bool enabled = true,
  });

  Future<void> setEnabled(int id, bool enabled);

  /// 记录本次触发时间（24h 去重靠它）。
  Future<void> markNotified(int id, DateTime at);

  Future<void> softDelete(int id);

  Future<void> restore(int id);
}
