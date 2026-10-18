import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/shopping_item.dart';
import '../providers/shopping_providers.dart';

/// 采购清单（工具箱插件 1）。
///
/// 三条硬要求（验收标准）：
/// 1. **3 步内记一条**：打开 → 工具箱 → 清单 → 打字回车（输入框常驻在顶部，不弹窗、不跳页）；
/// 2. 点整行 = 勾选，勾完立刻沉底（分组纯函数在 `domain/shopping_item.dart`）；
/// 3. 空态必须告诉用户「下一步做什么」，而不是只写「暂无数据」。
class ShoppingListPage extends ConsumerStatefulWidget {
  const ShoppingListPage({super.key});

  @override
  ConsumerState<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends ConsumerState<ShoppingListPage> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// 常用分类（长按行选分类时给候选；用户也能自己输）
  static const List<String> _presetCategories = [
    '蔬菜',
    '水果',
    '肉蛋',
    '主食',
    '日用品',
    '零食',
  ];

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 回车即添加，并把焦点留在输入框 —— 连续录入不用反复点。
  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(shoppingRepositoryProvider);
    await repo.add(name: text);
    if (!mounted) return;
    _input.clear();
    _focus.requestFocus();
  }

  Future<void> _restoreLastList() async {
    final repo = ref.read(shoppingRepositoryProvider);
    final count = await repo.resetChecked();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            count == 0 ? '没有已购项，清单已经是「全新」的' : '已把 $count 项变回未购，可以照着再买一遍',
          ),
        ),
      );
  }

  Future<void> _toggle(ShoppingItem item) async {
    await ref
        .read(shoppingRepositoryProvider)
        .setChecked(item.id, !item.checked);
  }

  Future<void> _delete(ShoppingItem item) async {
    final repo = ref.read(shoppingRepositoryProvider);
    await repo.softDelete(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除「${item.name}」'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => repo.restore(item.id),
          ),
        ),
      );
  }

  /// 长按改分类：让 `category` 字段真的可用（而不是永远「其他」）。
  Future<void> _pickCategory(ShoppingItem item) async {
    final categories = ref.read(shoppingCategoriesProvider).value ?? const [];
    final options = <String>[
      ..._presetCategories,
      ...categories.where((c) => !_presetCategories.contains(c)),
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  0,
                  AppDimens.pagePadding,
                  AppDimens.sectionHeaderGap,
                ),
                child: Text(
                  '「${item.name}」归到哪一类？',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding,
                ),
                child: Wrap(
                  spacing: AppDimens.chipGap,
                  runSpacing: AppDimens.chipGap,
                  children: [
                    for (final c in options)
                      ActionChip(
                        label: Text(c),
                        onPressed: () => Navigator.pop(sheetContext, c),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.cardGap),
              ListTile(
                leading: const Icon(Icons.playlist_remove),
                title: const Text('不分类（归到「其他」）'),
                onTap: () => Navigator.pop(sheetContext, ''),
              ),
              const SizedBox(height: AppDimens.cardGap),
            ],
          ),
        );
      },
    );

    if (picked == null || !mounted) return;
    await ref.read(shoppingRepositoryProvider).setCategory(item.id, picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncItems = ref.watch(shoppingItemsProvider);
    final groups = ref.watch(shoppingGroupsProvider);

    final Widget body;
    if (asyncItems.hasError && !asyncItems.hasValue) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '清单读取失败',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppDimens.sectionHeaderGap),
            FilledButton(
              onPressed: () => ref.invalidate(shoppingItemsProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    } else if (!asyncItems.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (groups.isEmpty) {
      body = const EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: '清单是空的',
        subtitle: '输入框就在上面，直接打字',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.only(
          top: AppDimens.cardGap,
          bottom: AppDimens.sectionGap * 2,
        ),
        children: [
          for (final group in groups) ...[
            _GroupHeader(group: group),
            for (final item in [...group.pending, ...group.done])
              _ItemRow(
                item: item,
                onTap: () => _toggle(item),
                onLongPress: () => _pickCategory(item),
                onDelete: () => _delete(item),
              ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('采购清单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: '从上次清单恢复',
            onPressed: _restoreLastList,
          ),
        ],
      ),
      body: Column(
        children: [
          // 常驻输入框：不弹窗、不跳页（验收的「3 步内记一条」靠它）
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.sectionHeaderGap,
              AppDimens.pagePadding,
              0,
            ),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding,
                vertical: AppDimens.cardPadding,
              ),
              child: TextField(
                controller: _input,
                focusNode: _focus,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: const Icon(Icons.add_shopping_cart),
                  hintText: '买什么？打完按回车就进清单',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: '添加',
                    onPressed: _add,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.chipGap,
              AppDimens.pagePadding,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '点一行 = 勾掉；左滑 = 删除；长按 = 改分类',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// 分类小标题（不是卡片，避免每类一张卡把屏幕撑得很碎）。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final ShoppingGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.cardGap,
        AppDimens.pagePadding,
        AppDimens.chipGap,
      ),
      child: Row(
        children: [
          Text(
            group.category,
            style: theme.textTheme.labelLarge?.copyWith(
              color: group.hasPending
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppDimens.chipGap),
          Text(
            '待买 ${group.pending.length} / 共 ${group.total}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单行：整行点击 = 勾选；左滑删除；长按改分类。
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final ShoppingItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = item.checked;

    return Dismissible(
      key: ValueKey('shopping-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimens.pagePadding),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.pagePadding,
          vertical: 2,
        ),
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding,
                vertical: AppDimens.cardGap,
              ),
              child: Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: done ? AppColors.success : AppColors.todo,
                  ),
                  const SizedBox(width: AppDimens.cardGap),
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: done
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (item.quantity > 1) ...[
                    const SizedBox(width: AppDimens.chipGap),
                    Text(
                      '×${item.quantity}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
