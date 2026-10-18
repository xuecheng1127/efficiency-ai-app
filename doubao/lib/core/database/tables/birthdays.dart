import 'package:drift/drift.dart';

/// birthdays 表（朋友生日插件）
@DataClassName('BirthdayRow')
class Birthdays extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get birthdayYear => integer().nullable()();
  IntColumn get birthdayMonth => integer()();
  IntColumn get birthdayDay => integer()();
  TextColumn get calendarType => text().withDefault(const Constant('solar'))();
  TextColumn get groupTag => text().withDefault(const Constant('其他'))();
  IntColumn get advanceDays => integer().withDefault(const Constant(3))();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
}
