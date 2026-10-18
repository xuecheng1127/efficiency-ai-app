import 'package:drift/drift.dart';

/// memos 表（T23 备忘录模块）
@DataClassName('MemoRow')
class Memos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  IntColumn get pinned => integer().withDefault(const Constant(0))();
  TextColumn get color => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
}
