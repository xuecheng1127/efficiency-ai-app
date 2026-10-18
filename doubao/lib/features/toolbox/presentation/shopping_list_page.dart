import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../providers/shopping_providers.dart';

class ShoppingListPage extends ConsumerStatefulWidget {
  const ShoppingListPage({super.key});

  @override
  ConsumerState<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends ConsumerState<ShoppingListPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await ref.read(shoppingRepositoryProvider).addItem(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(shoppingItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('采购清单'),
        actions: [
          IconButton(
            tooltip: '从上次的清单恢复',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              await ref.read(shoppingRepositoryProvider).resetAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复：所有勾选项重置为未购')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部输入框：回车即添加，不弹窗不跳页
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                hintText: '要买点什么？回车添加',
                prefixIcon: const Icon(Icons.add_shopping_cart),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _add,
                ),
              ),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('错误: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_basket_outlined,
                            size: 48, color: AppColors.neutral),
                        SizedBox(height: 12),
                        Text('清单是空的',
                            style: TextStyle(fontSize: 16, color: AppColors.neutral)),
                        SizedBox(height: 6),
                        Text('输入框就在上面，直接打字',
                            style: TextStyle(fontSize: 13, color: AppColors.neutral)),
                      ],
                    ),
                  );
                }
                // 分组：未购在上，已购在下
                final pending = list.where((e) => e.checked == 0).toList();
                final done = list.where((e) => e.checked == 1).toList();
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (pending.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Text('待购',
                            style: TextStyle(fontSize: 12, color: AppColors.neutral)),
                      ),
                      ...pending.map((e) => _Row(item: e)),
                    ],
                    if (done.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                        child: Text('已购',
                            style: TextStyle(fontSize: 12, color: AppColors.neutral)),
                      ),
                      ...done.map((e) => _Row(item: e)),
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

class _Row extends ConsumerWidget {
  final ShoppingItemRow item;
  const _Row({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(shoppingRepositoryProvider);
    final isChecked = item.checked == 1;

    return Slidable(
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => repo.softDelete(item.id),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '删除',
          ),
        ],
      ),
      child: ListTile(
        onTap: () => repo.toggleChecked(item.id, !isChecked),
        leading: Checkbox(
          value: isChecked,
          onChanged: (v) => repo.toggleChecked(item.id, v ?? false),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? AppColors.neutral : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              onPressed: () => repo.setQuantity(item.id, (item.quantity - 1).clamp(1, 99)),
            ),
            Text('×${item.quantity}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              onPressed: () => repo.setQuantity(item.id, item.quantity + 1),
            ),
          ],
        ),
      ),
    );
  }
}
