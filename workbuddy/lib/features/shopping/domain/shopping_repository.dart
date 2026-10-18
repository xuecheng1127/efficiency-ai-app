import 'shopping_item.dart';

/// 采购清单仓库（Domain 定接口 / Data 给实现）。
abstract interface class ShoppingRepository {
  /// 未删除的全部条目（排序由 UI 层的纯函数 `groupShoppingItems` 负责）。
  Stream<List<ShoppingItem>> watchAll();

  /// 添加一条。**空白名字不落库**（返回 null），避免清单里出现空行。
  Future<int?> add({required String name, String? category, int quantity = 1});

  /// 勾选 / 取消勾选（同时维护 `checkedAt`）。
  Future<void> setChecked(int id, bool checked);

  /// 改分类（null = 清空 → 归「其他」）。
  Future<void> setCategory(int id, String? category);

  /// 软删除。
  Future<void> softDelete(int id);

  /// 撤销删除（把 `deletedAt` 清掉）。
  Future<void> restore(int id);

  /// 「从上次清单恢复」：把所有已购项变回未购，返回受影响行数。
  Future<int> resetChecked();

  /// 历史分类（去重、非空），用于长按选分类时的候选。
  Future<List<String>> knownCategories();
}
