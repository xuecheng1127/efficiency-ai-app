import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/shopping_repository.dart';

final shoppingRepositoryProvider = Provider((ref) => ShoppingRepository(AppDatabase.instance));

final shoppingItemsProvider = StreamProvider((ref) {
  return ref.watch(shoppingRepositoryProvider).watchItems();
});
