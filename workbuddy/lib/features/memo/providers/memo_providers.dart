import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/memo_repository_impl.dart';
import '../domain/memo.dart';
import '../domain/memo_repository.dart';

final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  return MemoRepositoryImpl(ref.watch(databaseProvider));
});

/// 列表数据（仓库已按「置顶 + 更新时间」排好序，UI 只负责拆成两段）
final memoListProvider = StreamProvider<List<Memo>>((ref) {
  return ref.watch(memoRepositoryProvider).watchAll();
});

/// 搜索关键词（过滤 + 高亮共用）
class MemoSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String keyword) => state = keyword;

  void clear() => state = '';

  /// 纯函数式的过滤：置顶态不变，只筛内容（大小写不敏感）
  static List<Memo> filter(List<Memo> memos, String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return memos;
    return memos.where((m) => m.content.toLowerCase().contains(k)).toList();
  }
}

final memoSearchProvider = NotifierProvider<MemoSearchNotifier, String>(
  MemoSearchNotifier.new,
);
