import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/shopping_item.dart';
import '../domain/shopping_repository.dart';

/// 采购清单仓库的 Drift 实现（字段与 `shopping_items` 表一一对应）。
class ShoppingRepositoryImpl implements ShoppingRepository {
  ShoppingRepositoryImpl(this._db);

  final db.AppDatabase _db;

  ShoppingItem _toDomain(db.ShoppingItem row) => ShoppingItem(
    id: row.id,
    name: row.name,
    quantity: row.quantity,
    category: row.category,
    checked: row.checked,
    createdAt: row.createdAt,
    checkedAt: row.checkedAt,
    deletedAt: row.deletedAt,
  );

  SimpleSelectStatement<db.$ShoppingItemsTable, db.ShoppingItem> _alive() {
    return _db.select(_db.shoppingItems)
      ..where((t) => t.deletedAt.isNull());
  }

  @override
  Stream<List<ShoppingItem>> watchAll() {
    // 顺序交给 domain 的纯函数，这里只保证「稳定」：
    // 同一条数据在两次查询之间不能跳来跳去（createdAt 秒级精度 + id 兜底）。
    final query = _alive()
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    return query.watch().map(
      (rows) => [for (final r in rows) _toDomain(r)],
    );
  }

  @override
  Future<int?> add({
    required String name,
    String? category,
    int quantity = 1,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final c = category?.trim();
    return _db.into(_db.shoppingItems).insert(
      db.ShoppingItemsCompanion.insert(
        name: trimmed,
        quantity: Value(quantity < 1 ? 1 : quantity),
        category: Value(c == null || c.isEmpty ? null : c),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> setChecked(int id, bool checked) {
    return (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id))).write(
      db.ShoppingItemsCompanion(
        checked: Value(checked),
        checkedAt: Value(checked ? DateTime.now() : null),
      ),
    );
  }

  @override
  Future<void> setCategory(int id, String? category) {
    final c = category?.trim();
    return (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id))).write(
      db.ShoppingItemsCompanion(
        category: Value(c == null || c.isEmpty ? null : c),
      ),
    );
  }

  @override
  Future<void> softDelete(int id) {
    return (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id))).write(
      db.ShoppingItemsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> restore(int id) {
    return (_db.update(_db.shoppingItems)..where((t) => t.id.equals(id))).write(
      const db.ShoppingItemsCompanion(deletedAt: Value(null)),
    );
  }

  /// 「从上次清单恢复」：一次性把 checked 翻回 false。
  ///
  /// 只改 `checked` 与 `checkedAt`，**不动 createdAt** —— 恢复后清单顺序不会乱。
  @override
  Future<int> resetChecked() {
    return (_db.update(_db.shoppingItems)
          ..where((t) => t.deletedAt.isNull() & t.checked.equals(true)))
        .write(
          const db.ShoppingItemsCompanion(
            checked: Value(false),
            checkedAt: Value(null),
          ),
        );
  }

  @override
  Future<List<String>> knownCategories() async {
    final rows = await (_db.selectOnly(_db.shoppingItems)
          ..addColumns([_db.shoppingItems.category])
          ..where(
            _db.shoppingItems.deletedAt.isNull() &
                _db.shoppingItems.category.isNotNull(),
          )
          ..groupBy([_db.shoppingItems.category]))
        .get();
    final out = <String>[];
    for (final r in rows) {
      final v = r.read(_db.shoppingItems.category)?.trim();
      if (v != null && v.isNotEmpty) out.add(v);
    }
    out.sort();
    return out;
  }
}
