import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/diary_providers.dart';
import 'diary_editor_page.dart';

/// 日记列表页（T22）
class DiaryPage extends ConsumerWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaries = ref.watch(diariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('日记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: _DiarySearchDelegate(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DiaryEditorPage()),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: const Text('写日记'),
      ),
      body: diaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              message: '还没有日记\n点击下方按钮，写下第一篇',
              actionLabel: '写日记',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiaryEditorPage()),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppColors.pagePadding),
            itemCount: rows.length,
            itemBuilder: (ctx, i) {
              final d = rows[i];
              final date = DateTime.fromMillisecondsSinceEpoch(d.diaryDate);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(d.title.isEmpty
                      ? '${date.year}-${date.month}-${date.day}'
                      : d.title),
                  subtitle: Text(
                    d.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiaryEditorPage(diaryId: d.id),
                    ),
                  ),
                  onLongPress: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: const Text('删除日记？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('删除',
                                style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(diaryRepositoryProvider).softDelete(d.id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final int? maxLines;
  const _HighlightedText({required this.text, required this.query, this.maxLines});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
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

class _DiarySearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults(context);

  Widget _buildResults(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final asyncDiaries = ref.watch(diariesProvider);
        return asyncDiaries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) {
            final hits = query.isEmpty
                ? rows
                : rows.where((d) =>
                    d.content.contains(query) || d.title.contains(query)).toList();
            if (hits.isEmpty) {
              return const Center(child: Text('无匹配结果'));
            }
            return ListView.builder(
              itemCount: hits.length,
              itemBuilder: (ctx, i) {
                final d = hits[i];
                return ListTile(
                  title: _HighlightedText(
                    text: d.title.isEmpty ? '无标题' : d.title,
                    query: query,
                  ),
                  subtitle: _HighlightedText(
                    text: d.content,
                    query: query,
                    maxLines: 2,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiaryEditorPage(diaryId: d.id),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
