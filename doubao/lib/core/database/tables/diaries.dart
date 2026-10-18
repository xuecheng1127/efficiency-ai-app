import 'package:drift/drift.dart';

/// diaries 表（T22 日记模块）
@DataClassName('DiaryRow')
class Diaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get templateType =>
      text().withDefault(const Constant('lined'))();
  RealColumn get fontSize => real().withDefault(const Constant(16.0))();
  TextColumn get fontFamily => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get diaryDate => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
}
