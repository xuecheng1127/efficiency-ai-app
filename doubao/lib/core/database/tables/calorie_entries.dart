import 'package:drift/drift.dart';

/// calorie_entries 表（每日热量）
@DataClassName('CalorieEntryRow')
class CalorieEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entryDate => integer()(); // yyyyMMdd
  TextColumn get meal => text()(); // breakfast / lunch / dinner / snack
  TextColumn get name => text()();
  IntColumn get kcal => integer()();
  RealColumn get proteinG => real().withDefault(const Constant(0))();
  RealColumn get carbG => real().withDefault(const Constant(0))();
  RealColumn get fatG => real().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
}
