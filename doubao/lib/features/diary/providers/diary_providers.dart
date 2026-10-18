import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/diary_repository.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository(AppDatabase.instance);
});

final diariesProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(diaryRepositoryProvider).watchAll();
});
