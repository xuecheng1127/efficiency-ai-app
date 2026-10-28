import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/highlighted_text.dart';
import '../domain/diary_entry.dart';
import '../providers/diary_providers.dart';
import 'diary_editor_page.dart';
import 'diary_preview_page.dart';

/// 日记列表：按「今天 / 昨天 / 更早」分组 + 关键词搜索（命中高亮）。
class DiaryListPage extends ConsumerStatefulWidget {
  const DiaryListPage({super.key});

  @override
  ConsumerState<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends ConsumerState<DiaryListPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openEditor({int diaryId = 0}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DiaryEditorPage(diaryId: diaryId)),
    );
  }

  /// 点卡片 → **预览页**（引擎断行）→ 右上角「编辑」再进编辑器。
  Future<void> _openPreview(DiaryEntry entry) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiaryPreviewPage(diaryId: entry.id, initial: entry),
      ),
    );
  }

  Future<void> _confirmDelete(DiaryEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除日记'),
        content: Text(
          '确定删除「${entry.title.isEmpty ? entry.summary(maxChars: 16) : entry.title}」吗？'
          '\n（软删除，列表里会消失）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(diaryRepositoryProvider).softDelete(entry.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日记已删除')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncRows = ref.watch(diaryRowsProvider);
    final keyword = ref.watch(diarySearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('日记'),
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
              onChanged: (v) => ref.read(diarySearchProvider.notifier).set(v),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索标题或内容',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: keyword.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(diarySearchProvider.notifier).clear();
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
        icon: const Icon(Icons.edit_outlined),
        label: const Text('写日记'),
      ),
      body: asyncRows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(diaryRowsProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const _EmptyView();
          }

          // 搜索过滤（内存过滤：日记量级下足够，且能复用同一套高亮）
          final k = keyword.trim().toLowerCase();
          final filtered = k.isEmpty
              ? rows
              : rows
                    .where(
                      (r) =>
                          r.entry.title.toLowerCase().contains(k) ||
                          r.entry.content.toLowerCase().contains(k),
                    )
                    .toList();

          if (filtered.isEmpty) {
            return _NoHitView(keyword: keyword);
          }

          // 按桶分组（无命中关键词时保持默认分组）
          final groups = <DiaryDateBucket, List<DiaryListRow>>{};
          for (final row in filtered) {
            groups.putIfAbsent(row.bucket, () => []).add(row);
          }
          const order = [
            DiaryDateBucket.today,
            DiaryDateBucket.yesterday,
            DiaryDateBucket.earlier,
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              8,
              AppDimens.pagePadding,
              96,
            ),
            children: [
              for (final bucket in order)
                if (groups[bucket] != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: Text(
                      DiaryListRow.bucketLabel(bucket),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final row in groups[bucket]!)
                    _DiaryCard(
                      row: row,
                      keyword: keyword,
                      onTap: () => _openPreview(row.entry),
                      onLongPress: () => _confirmDelete(row.entry),
                    ),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({
    required this.row,
    required this.keyword,
    required this.onTap,
    required this.onLongPress,
  });

  final DiaryListRow row;
  final String keyword;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = row.entry;
    final title = e.title.trim();
    final body = e.summary();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.cardGap),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
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
                Row(
                  children: [
                    Icon(
                      e.isLined ? Icons.format_align_left : Icons.crop_square,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _dateLabel(e.diaryDate),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DiaryTemplateType.label(e.templateType),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (title.isNotEmpty) ...[
                  HighlightedText(
                    text: title,
                    keyword: keyword,
                    maxLines: 1,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                HighlightedText(
                  text: body.isEmpty ? '（空白）' : body,
                  keyword: keyword,
                  maxLines: 3,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: body.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _dateLabel(DateTime d) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${d.month}月${d.day}日 ${weekdays[d.weekday - 1]}';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    // 只留 FAB 一个入口：空态里再放一个「写第一篇」按钮是同一个动作的第二个入口，
    // 属于「少即是多」要砍的冗余（同时避免用户纠结点哪个）。
    return const EmptyState(
      icon: Icons.menu_book_outlined,
      title: '还没有日记',
      subtitle: '点右下角「写日记」，写下第一句就好',
    );
  }
}

class _NoHitView extends StatelessWidget {
  const _NoHitView({required this.keyword});

  final String keyword;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      title: '没有匹配的日记',
      subtitle: '换个关键词试试（当前：「$keyword」）',
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = message.length > 120
        ? '${message.substring(0, 120)}…'
        : message;
    return Column(
      children: [
        Expanded(
          child: EmptyState(
            icon: Icons.error_outline,
            title: '加载失败',
            subtitle: text,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ),
      ],
    );
  }
}
