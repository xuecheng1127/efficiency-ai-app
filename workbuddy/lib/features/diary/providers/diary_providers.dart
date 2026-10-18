import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/diary_media_store.dart';
import '../data/diary_repository_impl.dart';
import '../domain/diary_entry.dart';
import '../domain/diary_repository.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepositoryImpl(ref.watch(databaseProvider));
});

/// 图片存储（应用专属目录 `diary_media/`；DB 里只存相对路径）。
final diaryMediaStoreProvider = FutureProvider<DiaryMediaStore>((ref) {
  return DiaryMediaStore.open();
});

/// 列表数据：按「今天 / 昨天 / 更早」分桶，并按日期倒序。
///
/// 为什么分桶在 Provider 里做而不是页面里：日期边界依赖「当前时间」，
/// 放这里可以统一测，也能在跨零点后随流刷新重新计算。
final diaryRowsProvider = StreamProvider<List<DiaryListRow>>((ref) {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.watchAll().map((entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    return [
      for (final e in entries)
        DiaryListRow(
          entry: e,
          bucket: _bucketOf(e.diaryDate, today, yesterday),
        ),
    ];
  });
});

DiaryDateBucket _bucketOf(DateTime date, DateTime today, DateTime yesterday) {
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return DiaryDateBucket.today;
  if (d == yesterday) return DiaryDateBucket.yesterday;
  return DiaryDateBucket.earlier;
}

/// 搜索关键词（页面内过滤 + 高亮都用它）。
///
/// Riverpod 3 移除了 `StateProvider`（只剩 legacy 入口）。这里用最小的
/// [Notifier] 代替：一个字段、一个 setter，语义与 `StateProvider` 完全一致，
/// 但走的是新 API，不引入 `legacy.dart`。
class DiarySearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String keyword) => state = keyword;

  void clear() => state = '';
}

final diarySearchProvider = NotifierProvider<DiarySearchNotifier, String>(
  DiarySearchNotifier.new,
);

/// 详情（编辑页用；返回 null 表示新建）。
final diaryByIdProvider = FutureProvider.family<DiaryEntry?, int>((ref, id) {
  if (id <= 0) return Future.value(null);
  return ref.watch(diaryRepositoryProvider).findById(id);
});
