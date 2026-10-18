import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/shopping_repository_impl.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_repository.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepositoryImpl(ref.watch(databaseProvider));
});

/// 清单数据（响应式：勾选 / 删除 / 恢复都会立即反映到界面）。
final shoppingItemsProvider = StreamProvider<List<ShoppingItem>>((ref) {
  return ref.watch(shoppingRepositoryProvider).watchAll();
});

/// 分组后的展示数据。放在 Provider 里是为了让页面 `build` 只做渲染。
final shoppingGroupsProvider = Provider<List<ShoppingGroup>>((ref) {
  final items = ref.watch(shoppingItemsProvider).value ?? const <ShoppingItem>[];
  return groupShoppingItems(items);
});

/// 历史分类（长按选分类时的候选）。清单变化时自动重查。
final shoppingCategoriesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(shoppingItemsProvider);
  return ref.watch(shoppingRepositoryProvider).knownCategories();
});
