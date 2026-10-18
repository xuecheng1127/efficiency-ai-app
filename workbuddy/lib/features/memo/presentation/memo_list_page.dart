import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/highlighted_text.dart';
import '../domain/memo.dart';
import '../providers/memo_providers.dart';
import 'memo_editor_page.dart';

/// 备忘录列表（工具箱里的第 4 个插件，也是第一个**真正可用**的）。
///
/// 只做五件事（T23 规格 §3）：
/// 看列表（置顶在前）· 新建 · 编辑 · 删除（软删）· 搜索（命中高亮）。
/// 不做标签 / 富文本 / 双链 / 云同步 —— 用户定的「少即是多」。
class MemoListPage extends ConsumerStatefulWidget {
  const MemoListPage({super.key});

  @override
  ConsumerState<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends ConsumerState<MemoListPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openEditor({int memoId = 0}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MemoEditorPage(memoId: memoId)),
    );
  }

  /// 长按菜单：置顶 / 删除。两件事都是「一个动作」，不做多级菜单。
  Future<void> _showActions(Memo memo) async {
    // 先收起搜索框的焦点：否则弹层关掉后键盘会自动弹回来，
    // 用户只是想置顶/删除，却被键盘挡住半个列表。
    FocusManager.instance.primaryFocus?.unfocus();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                memo.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(memo.pinned ? '取消置顶' : '置顶'),
              onTap: () => Navigator.pop(sheetContext, 'pin'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: const Text(
                '删除',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    final repo = ref.read(memoRepositoryProvider);
    if (action == 'pin') {
      await repo.setPinned(memo.id, !memo.pinned);
      return;
    }
    if (action == 'delete') {
      final ok = await confirmDeleteMemo(context);
      if (ok != true) return;
      await repo.softDelete(memo.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('备忘已删除')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncMemos = ref.watch(memoListProvider);
    final keyword = ref.watch(memoSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('备忘录'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              0,
              AppDimens.pagePadding,
              10,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => ref.read(memoSearchProvider.notifier).set(v),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索备忘内容',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: keyword.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(memoSearchProvider.notifier).clear();
                        },
                      ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('记一条'),
      ),
      body: asyncMemos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: '加载失败',
          subtitle: '$e',
        ),
        data: (memos) {
          if (memos.isEmpty) return const _EmptyView();

          final filtered = MemoSearchNotifier.filter(memos, keyword);
          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              title: '没有匹配的备忘',
              subtitle: '换个关键词试试（当前：「$keyword」）',
            );
          }

          final pinned = filtered.where((m) => m.pinned).toList();
          final others = filtered.where((m) => !m.pinned).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              8,
              AppDimens.pagePadding,
              96,
            ),
            children: [
              if (pinned.isNotEmpty) ...[
                _SectionHeader(label: '置顶', count: pinned.length),
                for (final memo in pinned)
                  _MemoCard(
                    memo: memo,
                    keyword: keyword,
                    onTap: () => _openEditor(memoId: memo.id),
                    onLongPress: () => _showActions(memo),
                  ),
              ],
              if (others.isNotEmpty) ...[
                _SectionHeader(
                  label: pinned.isEmpty ? '全部备忘' : '其他',
                  count: others.length,
                ),
                for (final memo in others)
                  _MemoCard(
                    memo: memo,
                    keyword: keyword,
                    onTap: () => _openEditor(memoId: memo.id),
                    onLongPress: () => _showActions(memo),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({
    required this.memo,
    required this.keyword,
    required this.onTap,
    required this.onLongPress,
  });

  final Memo memo;
  final String keyword;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.cardGap),
      child: Material(
        color: memoPaperColor(theme, memo.color),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HighlightedText(
                  text: memo.summary(),
                  keyword: keyword,
                  maxLines: 3,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (memo.pinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.push_pin,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    Text(
                      _timeLabel(memo.updatedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 相对时间（今天 / 昨天 / M月d日），比绝对时间更符合"随手记"的语境
  static String _timeLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (day == today) return '今天 $hm';
    if (day == today.subtract(const Duration(days: 1))) return '昨天 $hm';
    if (t.year == now.year) return '${t.month}月${t.day}日';
    return '${t.year}年${t.month}月${t.day}日';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    // 与日记一致：空态只保留 FAB 一个入口，不做第二个同功能按钮
    return const EmptyState(
      icon: Icons.sticky_note_2_outlined,
      title: '还没有备忘',
      subtitle: '记点什么吧 —— 想到就写，不用分类',
    );
  }
}
