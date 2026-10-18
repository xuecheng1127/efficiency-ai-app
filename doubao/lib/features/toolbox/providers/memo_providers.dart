import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/memo_repository.dart';

final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  return MemoRepository(AppDatabase.instance);
});

final memosProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(memoRepositoryProvider).watchAll();
});
