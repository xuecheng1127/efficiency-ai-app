import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class ShoppingRepository {
  final AppDatabase db;
  ShoppingRepository(this.db);

  /// 未删条目流：未购在前，已购在后（按创建时间）
  Stream<List<ShoppingItemRow>> watchItems() {
    final query = db.select(db.shoppingItems)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.checked, mode: OrderingMode.asc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
      ]);
    return query.watch();
  }

  Future<int> addItem(String name, {String? category, int qty = 1}) {
    return db.into(db.shoppingItems).insert(
          ShoppingItemsCompanion.insert(
            name: name.trim(),
            quantity: Value(qty),
            category: Value(category),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> toggleChecked(int id, bool checked) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.shoppingItems)..where((t) => t.id.equals(id))).write(
      ShoppingItemsCompanion(
        checked: Value(checked ? 1 : 0),
        checkedAt: Value(checked ? ts : null),
      ),
    );
  }

  Future<void> setQuantity(int id, int qty) async {
    await (db.update(db.shoppingItems)..where((t) => t.id.equals(id)))
        .write(ShoppingItemsCompanion(quantity: Value(qty)));
  }

  Future<void> softDelete(int id) async {
    await (db.update(db.shoppingItems)..where((t) => t.id.equals(id)))
        .write(ShoppingItemsCompanion(
      deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// 模板恢复：把所有已购项重新变未购
  Future<void> resetAll() async {
    await (db.update(db.shoppingItems)
          ..where((t) => t.checked.equals(1) & t.deletedAt.isNull()))
        .write(const ShoppingItemsCompanion(
      checked: Value(0),
      checkedAt: Value(null),
    ));
  }
}
