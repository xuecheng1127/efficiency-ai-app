import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/location_reminder.dart';
import '../domain/location_repository.dart';

/// 途径提醒仓库的 Drift 实现。
class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._db);

  final db.AppDatabase _db;

  LocationReminder _toDomain(db.LocationReminder row) => LocationReminder(
    id: row.id,
    title: row.title,
    placeName: row.placeName,
    latitude: row.latitude,
    longitude: row.longitude,
    radiusMeters: row.radiusMeters,
    triggerOn: TriggerOn.byId(row.triggerOn),
    enabled: row.enabled,
    notifiedAt: row.notifiedAt,
    createdAt: row.createdAt,
    deletedAt: row.deletedAt,
  );

  @override
  Stream<List<LocationReminder>> watchAll() {
    final query = _db.select(_db.locationReminders)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.enabled), (t) => OrderingTerm.desc(t.id)]);
    return query.watch().map(
      (rows) => [for (final r in rows) _toDomain(r)],
    );
  }

  @override
  Future<List<LocationReminder>> allEnabled() async {
    final rows =
        await (_db.select(_db.locationReminders)..where(
              (t) => t.deletedAt.isNull() & t.enabled.equals(true),
            ))
            .get();
    return [for (final r in rows) _toDomain(r)];
  }

  @override
  Future<int?> create({
    required String title,
    required String placeName,
    required double latitude,
    required double longitude,
    int radiusMeters = 200,
    TriggerOn triggerOn = TriggerOn.enter,
    bool enabled = true,
  }) async {
    final t = title.trim();
    if (t.isEmpty) return null;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }
    return _db.into(_db.locationReminders).insert(
      db.LocationRemindersCompanion.insert(
        title: t,
        placeName: placeName.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusMeters: Value(radiusMeters < 50 ? 50 : radiusMeters),
        triggerOn: Value(triggerOn.id),
        enabled: Value(enabled),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> setEnabled(int id, bool enabled) {
    return (_db.update(_db.locationReminders)..where((t) => t.id.equals(id)))
        .write(db.LocationRemindersCompanion(enabled: Value(enabled)));
  }

  @override
  Future<void> markNotified(int id, DateTime at) {
    return (_db.update(_db.locationReminders)..where((t) => t.id.equals(id)))
        .write(db.LocationRemindersCompanion(notifiedAt: Value(at)));
  }

  @override
  Future<void> softDelete(int id) {
    return (_db.update(_db.locationReminders)..where((t) => t.id.equals(id)))
        .write(db.LocationRemindersCompanion(deletedAt: Value(DateTime.now())));
  }

  @override
  Future<void> restore(int id) {
    return (_db.update(_db.locationReminders)..where((t) => t.id.equals(id)))
        .write(const db.LocationRemindersCompanion(deletedAt: Value(null)));
  }
}
