import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../birthday/providers/birthday_providers.dart';
import '../../diary/domain/diary_block.dart';
import '../../diary/domain/diary_entry.dart';
import '../../diary/providers/diary_providers.dart';
import '../../memo/providers/memo_providers.dart';
import '../../shopping/providers/shopping_providers.dart';
import '../domain/search_doc.dart';

/// 搜索用的「全库快照」。
///
/// 五类数据各自已经是响应式 Stream（数据库一变就吐新值），这里只做**投影**：
/// 把五种实体压成统一的 [SearchDoc]，再交给纯函数 `searchDocs` 过滤。
/// 页面因此不需要知道任何实体的字段名。
class SearchCorpus {
  const SearchCorpus({required this.docs, required this.loading});

  final List<SearchDoc> docs;

  /// 至少一路数据还在首次加载（用来区分「真没有」和「还没读完」，
  /// 否则冷启动那一两帧会先闪一下「没有找到相关内容」）
  final bool loading;
}

/// 任务模板的只读投影。
///
/// 为什么不走 `TaskRepository`：搜索只需要 title + 规则摘要，
/// 为它给仓库接口加一个方法，三个测试 Fake 都得跟着改，收益不抵成本。
/// 这里直接读表，且只读、不写、不碰业务规则（过滤 archived 是唯一条件）。
final searchableTemplatesProvider = StreamProvider<List<SearchDoc>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.taskTemplates)
    ..where((t) => t.archivedAt.isNull());
  return query.watch().map(
    (rows) => [
      for (final row in rows)
        SearchDoc(
          category: SearchCategory.task,
          id: row.id,
          title: row.title,
          subtitle: _ruleSummary(
            type: row.type,
            repeatMode: row.repeatMode,
            repeatDays: row.repeatDays,
          ),
        ),
    ],
  );
});

/// `daily|weekly|once` + 周几 + 类型 → 一句人话，例如「每日 · 健身」。
String _ruleSummary({
  required String type,
  required String repeatMode,
  required String? repeatDays,
}) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final repeat = switch (repeatMode) {
    'weekly' => () {
      final days = (repeatDays ?? '')
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .where((d) => d >= 1 && d <= 7)
          .map((d) => weekdays[d - 1])
          .toList();
      return days.isEmpty ? '每周' : '每周 ${days.join('、')}';
    }(),
    'once' => '单次',
    _ => '每日',
  };
  final typeLabel = type == 'fitness' ? '健身' : '学习';
  return '$repeat · $typeLabel';
}

/// 组装五类文档。
///
/// 用 `value ?? []` 而不是 `when(...)`：哪一路先到就先显示哪一路，
/// 不必等最慢的一路；加载态单独用 [SearchCorpus.loading] 表达。
final searchCorpusProvider = Provider<SearchCorpus>((ref) {
  final templates = ref.watch(searchableTemplatesProvider);
  final diaries = ref.watch(diaryRowsProvider);
  final memos = ref.watch(memoListProvider);
  final shopping = ref.watch(shoppingItemsProvider);
  final birthdays = ref.watch(birthdayListProvider);

  final docs = <SearchDoc>[
    ...templates.value ?? const <SearchDoc>[],
    for (final row in diaries.value ?? const <DiaryListRow>[])
      SearchDoc(
        category: SearchCategory.diary,
        id: row.entry.id,
        title: row.entry.title.trim().isEmpty
            ? '（无标题）'
            : row.entry.title.trim(),
        // 日记正文里混着图片标记，先转纯文本再搜（否则搜「图片」会命中所有带图的日记）
        body: DiaryBlocks.plainText(row.entry.content),
        subtitle: '${row.entry.diaryDate.month}月${row.entry.diaryDate.day}日',
      ),
    for (final memo in memos.value ?? const [])
      SearchDoc(
        category: SearchCategory.memo,
        id: memo.id,
        title: memo.firstLine.isEmpty ? '（空备忘）' : memo.firstLine,
        body: memo.content,
        subtitle: memo.pinned ? '置顶备忘' : '备忘',
      ),
    for (final item in shopping.value ?? const [])
      SearchDoc(
        category: SearchCategory.shopping,
        id: item.id,
        title: item.name,
        subtitle: [
          item.categoryLabel,
          if (item.quantity > 1) '×${item.quantity}',
          if (item.checked) '已购',
        ].join(' · '),
      ),
    for (final b in birthdays.value ?? const [])
      SearchDoc(
        category: SearchCategory.birthday,
        id: b.id,
        title: b.name,
        body: b.notes ?? '',
        subtitle: '${b.month}月${b.day}日 · ${b.calendar.label}',
      ),
  ];

  final loading =
      (templates.isLoading && !templates.hasValue) ||
      (diaries.isLoading && !diaries.hasValue) ||
      (memos.isLoading && !memos.hasValue) ||
      (shopping.isLoading && !shopping.hasValue) ||
      (birthdays.isLoading && !birthdays.hasValue);

  return SearchCorpus(docs: docs, loading: loading);
});
