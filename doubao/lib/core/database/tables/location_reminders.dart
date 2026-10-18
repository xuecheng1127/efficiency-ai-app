import 'package:drift/drift.dart';

/// location_reminders 表（顺路提醒）
@DataClassName('LocationReminderRow')
class LocationReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get placeName => text()();
  TextColumn get placeAddress => text().nullable()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get radiusMeters => integer().withDefault(const Constant(200))();
  TextColumn get triggerOn => text().withDefault(const Constant('enter'))();
  IntColumn get enabled => integer().withDefault(const Constant(1))();
  IntColumn get notifiedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
}
