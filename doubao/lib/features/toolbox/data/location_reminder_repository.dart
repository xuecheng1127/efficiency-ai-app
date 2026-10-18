import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class LocationReminderRepository {
  final AppDatabase db;
  LocationReminderRepository(this.db);

  Stream<List<LocationReminderRow>> watchAll() {
    return (db.select(db.locationReminders)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<int> add({
    required String title,
    required String placeName,
    required double lat,
    required double lng,
    String? address,
    int radius = 200,
    String triggerOn = 'enter',
  }) {
    return db.into(db.locationReminders).insert(
          LocationRemindersCompanion.insert(
            title: title,
            placeName: placeName,
            latitude: lat,
            longitude: lng,
            placeAddress: Value(address),
            radiusMeters: Value(radius),
            triggerOn: Value(triggerOn),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await (db.update(db.locationReminders)..where((t) => t.id.equals(id)))
        .write(LocationRemindersCompanion(enabled: Value(enabled ? 1 : 0)));
  }

  Future<void> softDelete(int id) async {
    await (db.update(db.locationReminders)..where((t) => t.id.equals(id)))
        .write(LocationRemindersCompanion(
      deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// 24 小时内不重复提醒
  Future<bool> shouldNotify(LocationReminderRow r) async {
    if (r.notifiedAt == null) return true;
    return DateTime.now().millisecondsSinceEpoch - r.notifiedAt! > 86400000;
  }

  Future<void> markNotified(int id) async {
    await (db.update(db.locationReminders)..where((t) => t.id.equals(id)))
        .write(LocationRemindersCompanion(
      notifiedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// 粗略距离（米），Haversine
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
