import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/highlighted_text.dart';
import '../../birthday/domain/birthday.dart';
import '../../birthday/presentation/birthday_edit_page.dart';
import '../../birthday/providers/birthday_providers.dart';
import '../../diary/presentation/diary_preview_page.dart';
import '../../home/providers/home_tab.dart';
import '../../memo/presentation/memo_editor_page.dart';
import '../../shopping/presentation/shopping_list_page.dart';
import '../domain/search_doc.dart';
import '../domain/search_engine.dart';
import '../providers/search_providers.dart';

/// 全局搜索：一次搜完 5 类数据（任务模板 / 日记 / 备忘 / 采购 / 生日）。
///
/// 三条刻意的产品决定：
/// 1. **空关键词不返回全部**：这里不是数据库浏览器，用户是带着词来的；
/// 2. **无结果只在列表区显示空态**，不弹 SnackBar —— 搜索框就在上面，
///    你每敲一个字都可能「无结果」，弹提示会变成持续的干扰；
/// 3. **分组顺序固定**（任务→日记→备忘→采购→生日），不按命中数重排，
///    这样同一个词连续搜两次，结果的位置不会跳。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  String _keyword = '';

  /// 用户点了「查看全部」的类型（不截断）
  final Set<SearchCategory> _expanded = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onKeywordChanged(String value) {
    setState(() {
      _keyword = value;
      // 换了词，之前的「查看全部」不再适用（新结果可能只有 1 条）
      _expanded.clear();
    });
  }

  void _clear() {
    _controller.clear();
    _onKeywordChanged('');
  }

  Future<void> _open(SearchDoc doc) {
    switch (doc.category) {
      case SearchCategory.task:
        return _openTaskSheet(doc);
      case SearchCategory.diary:
        return Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => DiaryPreviewPage(diaryId: doc.id)),
        );
      case SearchCategory.memo:
        return Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => MemoEditorPage(memoId: doc.id)),
        );
      case SearchCategory.shopping:
        return Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const ShoppingListPage()),
        );
      case SearchCategory.birthday:
        final birthday = _findBirthday(doc.id);
        if (birthday == null) return Future<void>.value();
        return Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => BirthdayEditPage(existing: birthday),
          ),
        );
    }
  }

  /// 列表里只有 id，回原始流里取完整实体（生日编辑页需要整条记录）。
  Birthday? _findBirthday(int id) {
    for (final b
        in ref.read(birthdayListProvider).value ?? const <Birthday>[]) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// 任务模板没有独立的详情/编辑页（V1 只有「新建」），
  /// 所以这里给一张只读详情面板 + 一个明确的去处，而不是点了没反应的死路。
  Future<void> _openTaskSheet(SearchDoc doc) async {
    final goTasks = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.checklist_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(doc.title),
                subtitle: Text(doc.subtitle),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.today_outlined),
                title: const Text('去任务页看今天'),
                subtitle: const Text('任务模板没有单独详情页，今天的实例在任务页'),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        );
      },
    );

    if (goTasks == true && mounted) {
      ref.read(homeTabProvider.notifier).select(1);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corpus = ref.watch(searchCorpusProvider);
    final hits = searchDocs(corpus.docs, _keyword);
    final hasKeyword = _keyword.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onKeywordChanged,
          decoration: InputDecoration(
            hintText: '搜索任务、日记、备忘、采购、生日',
            border: InputBorder.none,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          if (hasKeyword)
            IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.close),
              onPressed: _clear,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: !hasKeyword
          ? const EmptyState(
              icon: Icons.search,
              title: '搜索全部内容',
              subtitle: '任务 / 日记 / 备忘 / 采购 / 生日，输入关键词即可',
            )
          : hits.isEmpty
          ? corpus.loading
                ? const Center(child: CircularProgressIndicator())
                : EmptyState(
                    icon: Icons.search_off,
                    title: '没有找到相关内容',
                    subtitle: '「${_keyword.trim()}」没有命中，换个更短的关键词试试',
                  )
          : _buildResults(context, hits),
    );
  }

  Widget _buildResults(BuildContext context, List<SearchHit> hits) {
    final groups = groupSearchHits(hits, expanded: _expanded);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: AppDimens.sectionGap * 2),
      children: [
        for (final group in groups) ...[
          _GroupHeader(
            group: group,
            onExpand: () {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _expanded.add(group.category));
            },
          ),
          for (final hit in group.hits)
            _ResultTile(
              hit: hit,
              keyword: _keyword,
              onTap: () => _open(hit.doc),
            ),
        ],
      ],
    );
  }
}

/// 分组标题：图标 + 类型名 + 条数 + 「查看全部」
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.onExpand});

  final SearchGroup group;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.sectionGap,
        AppDimens.chipGap,
        0,
      ),
      child: Row(
        children: [
          Icon(
            _iconOf(group.category),
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppDimens.chipGap),
          Text(
            group.category.label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${group.total}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (group.hasMore)
            TextButton(
              onPressed: onExpand,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text('查看全部 ${group.total}'),
            ),
        ],
      ),
    );
  }
}

/// 单条结果
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.hit,
    required this.keyword,
    required this.onTap,
  });

  final SearchHit hit;
  final String keyword;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = hit.doc;
    final snippet = hit.snippet.trim();
    // 备忘的首行和正文同源，正文片段等于标题时不再重复一行
    final showSnippet = snippet.isNotEmpty && snippet != doc.title.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        2,
        AppDimens.pagePadding,
        2,
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.cardGap,
              vertical: 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _iconOf(doc.category),
                      size: 17,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.cardGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HighlightedText(
                        text: doc.title,
                        keyword: keyword,
                        maxLines: 2,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showSnippet) ...[
                        const SizedBox(height: 2),
                        HighlightedText(
                          text: snippet,
                          keyword: keyword,
                          maxLines: 2,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (doc.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          doc.subtitle,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconOf(SearchCategory category) => switch (category) {
  SearchCategory.task => Icons.checklist_rounded,
  SearchCategory.diary => Icons.auto_stories_outlined,
  SearchCategory.memo => Icons.sticky_note_2_outlined,
  SearchCategory.shopping => Icons.shopping_basket_outlined,
  SearchCategory.birthday => Icons.cake_outlined,
};

/// AppBar 上的搜索入口（四个 tab 共用同一个图标与行为）。
class SearchAction extends StatelessWidget {
  const SearchAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '搜索',
      icon: const Icon(Icons.search),
      onPressed: () => Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const SearchPage())),
    );
  }
}
