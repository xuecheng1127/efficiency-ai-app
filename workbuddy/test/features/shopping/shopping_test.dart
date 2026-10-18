import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart'
    hide ShoppingItem;
import 'package:efficiency_app/features/shopping/data/shopping_repository_impl.dart';
import 'package:efficiency_app/features/shopping/domain/shopping_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// 采购清单：仓库行为（内存 SQLite）+ 分组纯函数。
void main() {
  group('ShoppingRepositoryImpl（内存 SQLite）', () {
    late AppDatabase db;
    late ShoppingRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = ShoppingRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('空白名字不落库（不产生空行）', () async {
      expect(await repo.add(name: '   '), isNull);
      expect(await repo.watchAll().first, isEmpty);
    });

    test('添加后能读到，默认未勾选、数量 1、分类为空', () async {
      final id = await repo.add(name: ' 牛奶 ');
      expect(id, isNotNull);
      final items = await repo.watchAll().first;
      expect(items, hasLength(1));
      expect(items.single.name, '牛奶', reason: '名字要 trim');
      expect(items.single.checked, isFalse);
      expect(items.single.quantity, 1);
      expect(items.single.category, isNull);
    });

    test('勾选写 checkedAt；取消勾选清空它', () async {
      final id = (await repo.add(name: '鸡蛋'))!;
      await repo.setChecked(id, true);
      var item = (await repo.watchAll().first).single;
      expect(item.checked, isTrue);
      expect(item.checkedAt, isNotNull);

      await repo.setChecked(id, false);
      item = (await repo.watchAll().first).single;
      expect(item.checked, isFalse);
      expect(item.checkedAt, isNull);
    });

    test('软删除后不再出现；restore 能把它找回来（撤销）', () async {
      final id = (await repo.add(name: '面包'))!;
      await repo.softDelete(id);
      expect(await repo.watchAll().first, isEmpty);

      await repo.restore(id);
      final items = await repo.watchAll().first;
      expect(items, hasLength(1));
      expect(items.single.name, '面包');
    });

    test('「从上次清单恢复」把已购全部变回未购，并返回条数', () async {
      final a = (await repo.add(name: 'A'))!;
      final b = (await repo.add(name: 'B'))!;
      await repo.add(name: 'C');
      await repo.setChecked(a, true);
      await repo.setChecked(b, true);

      final count = await repo.resetChecked();
      expect(count, 2);

      final items = await repo.watchAll().first;
      expect(items.every((i) => !i.checked), isTrue);
      expect(items.every((i) => i.checkedAt == null), isTrue);
      expect(items, hasLength(3), reason: '恢复不能删数据');
    });

    test('setCategory 支持改分类与清空（null → 「其他」）', () async {
      final id = (await repo.add(name: '西红柿'))!;
      await repo.setCategory(id, '蔬菜');
      expect((await repo.watchAll().first).single.categoryLabel, '蔬菜');

      await repo.setCategory(id, null);
      expect((await repo.watchAll().first).single.categoryLabel, kOtherCategory);
    });

    test('knownCategories 去重且忽略空分类', () async {
      final a = (await repo.add(name: 'A', category: '蔬菜'))!;
      await repo.add(name: 'B', category: '蔬菜');
      await repo.add(name: 'C', category: '水果');
      await repo.add(name: 'D');
      expect(await repo.knownCategories(), ['水果', '蔬菜']);

      await repo.setCategory(a, '');
      expect(await repo.knownCategories(), ['水果', '蔬菜']);
    });
  });

  group('groupShoppingItems（纯函数）', () {
    ShoppingItem item({
      required int id,
      required String name,
      String? category,
      bool checked = false,
      int? minutesAgo,
    }) {
      final base = DateTime(2026, 10, 18, 12);
      return ShoppingItem(
        id: id,
        name: name,
        quantity: 1,
        category: category,
        checked: checked,
        createdAt: base.subtract(Duration(minutes: minutesAgo ?? id)),
        checkedAt: checked ? base : null,
      );
    }

    test('未分类归「其他」', () {
      final groups = groupShoppingItems([
        item(id: 1, name: 'A'),
        item(id: 2, name: 'B', category: '   '),
      ]);
      expect(groups.single.category, kOtherCategory);
      expect(groups.single.total, 2);
    });

    test('同一分类里未购在上、已购沉底', () {
      final groups = groupShoppingItems([
        item(id: 1, name: '已买', category: '蔬菜', checked: true),
        item(id: 2, name: '没买', category: '蔬菜'),
      ]);
      final g = groups.single;
      expect(g.pending.map((e) => e.name), ['没买']);
      expect(g.done.map((e) => e.name), ['已买']);
    });

    test('还有未购的组排在纯已购的组前面；「其他」同类里垫底', () {
      final groups = groupShoppingItems([
        item(id: 1, name: 'A', category: '水果', checked: true),
        item(id: 2, name: 'B', category: '蔬菜'),
        item(id: 3, name: 'C'),
      ]);
      expect(groups.map((g) => g.category), ['蔬菜', kOtherCategory, '水果']);
      expect(groups.last.hasPending, isFalse);
    });

    test('已删除的条目不出现在分组里', () {
      final alive = item(id: 1, name: 'A');
      final deleted = item(id: 2, name: 'B')
          .copyWith(deletedAt: DateTime(2026, 10, 18));
      final groups = groupShoppingItems([alive, deleted]);
      expect(groups.single.total, 1);
    });

    test('pendingCount 只数未购且未删除', () {
      expect(
        pendingCount([
          item(id: 1, name: 'A'),
          item(id: 2, name: 'B', checked: true),
          item(id: 3, name: 'C')
              .copyWith(deletedAt: DateTime(2026, 10, 18)),
        ]),
        1,
      );
    });
  });
}
