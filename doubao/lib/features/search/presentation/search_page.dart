import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../diary/presentation/diary_editor_page.dart';
import '../../diary/presentation/diary_preview_page.dart';
import '../../diary/providers/diary_providers.dart';
import '../../task/presentation/add_task_page.dart';
import '../../task/providers/task_providers.dart';
import '../../toolbox/presentation/birthday_list_page.dart';
import '../../toolbox/presentation/memo_editor_page.dart';
import '../../toolbox/presentation/shopping_list_page.dart';
import '../../toolbox/providers/birthday_providers.dart';
import '../../toolbox/providers/memo_providers.dart';
import '../../toolbox/providers/shopping_providers.dart';
import '../search_engine.dart';

/// 全局搜索页（R3）：跨任务 / 日记 / 备忘录 / 采购清单 / 朋友生日五类数据。
///
/// 匹配与分组由纯函数 [runSearch] 完成；本页只负责取数、渲染、跳转。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';
  final Set<SearchKind> _expanded = {};

  static const _order = [
    SearchKind.task,
    SearchKind.diary,
    SearchKind.memo,
    SearchKind.shopping,
    SearchKind.birthday,
  ];

  static const _perGroup = 5;

  static const _kindIcon = <SearchKind, IconData>{
    SearchKind.task: Icons.checklist_outlined,
    SearchKind.diary: Icons.menu_book_outlined,
    SearchKind.memo: Icons.sticky_note_2_outlined,
    SearchKind.shopping: Icons.shopping_basket_outlined,
    SearchKind.birthday: Icons.cake_outlined,
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SearchCandidate> _buildCandidates() {
    final candidates = <SearchCandidate>[];

    final templates = ref.watch(allTemplatesProvider).valueOrNull ?? [];
    for (final t in templates) {
      candidates.add(SearchCandidate(
        kind: SearchKind.task,
        id: t.id!,
        title: t.title,
        matchFields: [t.title],
      ));
    }

    final diaries = ref.watch(diariesProvider).valueOrNull ?? [];
    for (final d in diaries) {
      final date = DateTime.fromMillisecondsSinceEpoch(d.diaryDate);
      final title = d.title.isEmpty
          ? '${date.year}-${date.month}-${date.day}'
          : d.title;
      candidates.add(SearchCandidate(
        kind: SearchKind.diary,
        id: d.id,
        title: title,
        subtitle: d.content,
        matchFields: [d.title, d.content],
      ));
    }

    final memos = ref.watch(memosProvider).valueOrNull ?? [];
    for (final m in memos) {
      final firstLine = m.content.split('\n').first.trim();
      candidates.add(SearchCandidate(
        kind: SearchKind.memo,
        id: m.id,
        title: firstLine.isEmpty ? '备忘录' : firstLine,
        subtitle: m.content,
        matchFields: [m.content],
      ));
    }

    final shops = ref.watch(shoppingItemsProvider).valueOrNull ?? [];
    for (final s in shops) {
      candidates.add(SearchCandidate(
        kind: SearchKind.shopping,
        id: s.id,
        title: s.name,
        subtitle: s.quantity > 1 ? '×${s.quantity}' : '',
        matchFields: [s.name],
      ));
    }

    final birthdays = ref.watch(birthdaysProvider).valueOrNull ?? [];
    for (final b in birthdays) {
      candidates.add(SearchCandidate(
        kind: SearchKind.birthday,
        id: b.id,
        title: b.name,
        subtitle: b.notes ?? '',
        matchFields: [b.name, b.notes ?? ''],
      ));
    }

    return candidates;
  }

  void _openHit(SearchHit hit) {
    switch (hit.kind) {
      case SearchKind.task:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddTaskPage(taskId: hit.id)),
        );
      case SearchKind.diary:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _DiaryPreviewEntry(
              diaryId: hit.id,
              title: hit.title,
              content: hit.subtitle,
            ),
          ),
        );
      case SearchKind.memo:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MemoEditorPage(memoId: hit.id)),
        );
      case SearchKind.shopping:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ShoppingListPage()),
        );
      case SearchKind.birthday:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BirthdayListPage()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = runSearch(_buildCandidates(), _query);
    final searching = _query.trim().isNotEmpty;

    return Semantics(
      namesRoute: true,
      label: '全局搜索',
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: '搜索任务、日记、备忘录、采购、生日',
              border: InputBorder.none,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (_query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: '清空搜索',
                onPressed: () {
                  _controller.clear();
                  setState(() {
                    _query = '';
                    _expanded.clear();
                  });
                },
              ),
          ],
        ),
        body: !searching
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    '输入关键词，搜索任务、日记、备忘录、采购清单和朋友生日',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.neutral, fontSize: 14),
                  ),
                ),
              )
            : result.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off,
                    message: '没有找到相关内容',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppColors.pagePadding),
                    itemCount: _order.length,
                    itemBuilder: (context, index) {
                      final kind = _order[index];
                      final hits = result.groups[kind];
                      if (hits == null || hits.isEmpty) return const SizedBox.shrink();

                      final expanded = _expanded.contains(kind);
                      final visible = expanded
                          ? hits
                          : hits.take(_perGroup).toList();
                      final hasMore = hits.length > _perGroup;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Row(
                              children: [
                                ExcludeSemantics(
                                  child: Icon(_kindIcon[kind],
                                      size: 16, color: AppColors.neutral),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${kind.label}（${hits.length}）',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.neutral,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Card(
                            child: Column(
                              children: [
                                for (final hit in visible)
                                  MergeSemantics(
                                    child: ListTile(
                                      leading: ExcludeSemantics(
                                        child: Icon(_kindIcon[kind],
                                            size: 20, color: AppColors.primary),
                                      ),
                                      title: _HighlightedText(
                                        text: hit.title,
                                        query: _query,
                                      ),
                                      subtitle: hit.subtitle.isEmpty
                                          ? null
                                          : _HighlightedText(
                                              text: hit.subtitle,
                                              query: _query,
                                              maxLines: 2,
                                            ),
                                      onTap: () => _openHit(hit),
                                    ),
                                  ),
                                if (hasMore)
                                  TextButton(
                                    onPressed: () => setState(() {
                                      if (expanded) {
                                        _expanded.remove(kind);
                                      } else {
                                        _expanded.add(kind);
                                      }
                                    }),
                                    child: Text(expanded ? '收起' : '查看全部（${hits.length} 条）'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}

/// 日记预览入口（只读预览 + 右上角编辑），结构与日记列表保持一致
class _DiaryPreviewEntry extends StatelessWidget {
  final int diaryId;
  final String title;
  final String content;

  const _DiaryPreviewEntry({
    required this.diaryId,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? '日记' : title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => DiaryEditorPage(diaryId: diaryId),
              ),
            ),
          ),
        ],
      ),
      body: DiaryPreviewPage(title: title, content: content),
    );
  }
}

/// 关键词高亮（与日记列表同一套规则：小写后子串命中，黄色底标注）
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final int? maxLines;

  const _HighlightedText({
    required this.text,
    required this.query,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty || text.isEmpty) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final q = query.trim().toLowerCase();
    int i = 0;
    while (i < text.length) {
      final idx = lower.indexOf(q, i);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (idx > i) spans.add(TextSpan(text: text.substring(i, idx)));
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: TextStyle(backgroundColor: Colors.yellow.withOpacity(0.3)),
      ));
      i = idx + q.length;
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
