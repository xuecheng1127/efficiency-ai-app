import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/memo_providers.dart';
import 'memo_editor_page.dart';

class MemoListPage extends ConsumerStatefulWidget {
  const MemoListPage({super.key});

  @override
  ConsumerState<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends ConsumerState<MemoListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final memos = ref.watch(memosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('备忘录')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoEditorPage()),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.note_add),
        label: const Text('记一笔'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索备忘...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: memos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (rows) {
                final filtered = _query.isEmpty
                    ? rows
                    : rows.where((m) => m.content.contains(_query)).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: _query.isEmpty
                        ? Icons.sticky_note_2_outlined
                        : Icons.search_off,
                    message: _query.isEmpty
                        ? '还没有备忘\n记点什么吧'
                        : '无匹配结果',
                    actionLabel: _query.isEmpty ? '记一笔' : null,
                    onAction: _query.isEmpty
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const MemoEditorPage()),
                            )
                        : null,
                  );
                }
                final pinned =
                    filtered.where((m) => m.pinned == 1).toList();
                final normal =
                    filtered.where((m) => m.pinned == 0).toList();
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (pinned.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('置顶',
                            style:
                                TextStyle(color: AppColors.warning, fontSize: 12)),
                      ),
                      ...pinned.map((m) =>
                          _MemoCard(memo: m, query: _query)),
                      const SizedBox(height: 16),
                    ],
                    if (normal.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('全部',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                      ...normal.map((m) =>
                          _MemoCard(memo: m, query: _query)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoCard extends ConsumerWidget {
  final dynamic memo;
  final String query;
  const _MemoCard({required this.memo, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateTime.fromMillisecondsSinceEpoch(memo.updatedAt);
    return Card(
      child: ListTile(
        leading: Icon(
          memo.pinned == 1 ? Icons.push_pin : Icons.sticky_note_2_outlined,
          color: memo.pinned == 1 ? AppColors.warning : AppColors.primary,
        ),
        title: _buildHighlighted(memo.content),
        subtitle: Text(
            '${time.month}-${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MemoEditorPage(memoId: memo.id)),
        ),
        onLongPress: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.push_pin),
                    title: Text(memo.pinned == 1 ? '取消置顶' : '置顶'),
                    onTap: () => Navigator.pop(ctx, 'pin'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                    title: const Text('删除', style: TextStyle(color: AppColors.danger)),
                    onTap: () => Navigator.pop(ctx, 'delete'),
                  ),
                ],
              ),
            ),
          );
          if (action == 'pin') {
            await ref.read(memoRepositoryProvider).upsert(
                  id: memo.id,
                  content: memo.content,
                  pinned: memo.pinned != 1,
                );
          } else if (action == 'delete') {
            await ref.read(memoRepositoryProvider).softDelete(memo.id);
          }
        },
      ),
    );
  }

  Widget _buildHighlighted(String text) {
    if (query.isEmpty) {
      return Text(text, maxLines: 3, overflow: TextOverflow.ellipsis);
    }
    final spans = <TextSpan>[];
    int i = 0;
    while (i < text.length) {
      if (i + query.length <= text.length &&
          text.substring(i, i + query.length) == query) {
        spans.add(TextSpan(
          text: query,
          style: const TextStyle(
              backgroundColor: Colors.yellow,
              fontWeight: FontWeight.bold),
        ));
        i += query.length;
      } else {
        int j = i;
        while (j < text.length &&
            !(j + query.length <= text.length &&
                text.substring(j, j + query.length) == query)) {
          j++;
        }
        spans.add(TextSpan(text: text.substring(i, j)));
        i = j;
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
