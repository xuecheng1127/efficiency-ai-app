import 'package:drift/drift.dart';

/// shopping_items 表（采购清单插件）
@DataClassName('ShoppingItemRow')
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get category => text().nullable()();
  IntColumn get checked => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get checkedAt => integer().nullable()();
  IntColumn get deletedAt => integer().nullable()();
}
