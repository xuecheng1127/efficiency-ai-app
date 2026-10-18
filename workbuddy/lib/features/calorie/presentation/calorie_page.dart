import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/calorie.dart';
import '../providers/calorie_providers.dart';
import 'calorie_goal_page.dart';

/// 每日热量（工具箱插件 3）。
///
/// 验收口径「打开到记完一条 ≤ 3 步」：
/// 工具箱 → 每日热量 → 输入食物名+热量 → 点 +（输入框常驻底部，餐次按时间自动选）。
class CaloriePage extends ConsumerStatefulWidget {
  const CaloriePage({super.key});

  @override
  ConsumerState<CaloriePage> createState() => _CaloriePageState();
}

class _CaloriePageState extends ConsumerState<CaloriePage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _kcal = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _kcalFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (_name.text != _query) setState(() => _query = _name.text.trim());
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _nameFocus.dispose();
    _kcalFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final kcal = int.tryParse(_kcal.text.trim()) ?? 0;
    if (name.isEmpty || kcal <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('填个食物名和热量（正数）再记')));
      return;
    }
    final now = DateTime.now();
    await ref
        .read(calorieRepositoryProvider)
        .add(
          date: now,
          meal: MealType.forHour(now.hour),
          name: name,
          kcal: kcal,
        );
    if (!mounted) return;
    _name.clear();
    _kcal.clear();
    _nameFocus.requestFocus();
    ref.invalidate(foodHistoryProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '已记入${MealType.forHour(now.hour).label}：$name $kcal kcal',
          ),
        ),
      );
  }

  Future<void> _delete(CalorieEntry entry) async {
    final repo = ref.read(calorieRepositoryProvider);
    await repo.softDelete(entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除「${entry.name}」'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => repo.restore(entry.id),
          ),
        ),
      );
  }

  void _useSuggestion(String name) {
    _name.text = name;
    _name.selection = TextSelection.collapsed(offset: name.length);
    _kcalFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncEntries = ref.watch(todayCalorieEntriesProvider);
    final groups = ref.watch(todayMealGroupsProvider);
    final totals = ref.watch(todayCalorieTotalsProvider);
    final target = ref.watch(calorieTargetProvider);
    final history = ref.watch(foodHistoryProvider).value ?? const <String>[];
    final now = DateTime.now();
    final autoMeal = MealType.forHour(now.hour);

    final suggestions = _query.isEmpty
        ? history.take(6).toList()
        : history
              .where((h) => h.contains(_query) && h != _query)
              .take(6)
              .toList();

    final Widget list;
    if (asyncEntries.hasError && !asyncEntries.hasValue) {
      list = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '热量数据读取失败',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppDimens.sectionHeaderGap),
            FilledButton(
              onPressed: () => ref.invalidate(todayCalorieEntriesProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    } else if (!asyncEntries.hasValue) {
      list = const Center(child: CircularProgressIndicator());
    } else if (groups.isEmpty) {
      list = const EmptyState(
        icon: Icons.restaurant_outlined,
        title: '今天还没记录',
        subtitle: '在下面输入食物和热量，点右边 + 就记上了',
      );
    } else {
      list = ListView(
        padding: const EdgeInsets.only(
          top: AppDimens.chipGap,
          bottom: AppDimens.cardGap,
        ),
        children: [
          for (final group in groups) ...[
            _MealHeader(group: group),
            for (final entry in group.entries)
              _EntryRow(entry: entry, onDelete: () => _delete(entry)),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('每日热量'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: '目标设置',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const CalorieGoalPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TodaySummary(totals: totals, target: target),
          Expanded(child: list),
          // 常驻快速添加（不弹窗、不跳页）
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.chipGap,
              AppDimens.pagePadding,
              AppDimens.cardGap,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '将记入「${autoMeal.label}」· 按当前时间 ${now.hour.toString().padLeft(2, '0')}:'
                    '${now.minute.toString().padLeft(2, '0')} 自动判断',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimens.chipGap),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _name,
                          focusNode: _nameFocus,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: '食物名',
                            prefixIcon: Icon(Icons.restaurant_menu, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.chipGap),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _kcal,
                          focusNode: _kcalFocus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _add(),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: 'kcal',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.chipGap),
                      IconButton.filled(
                        onPressed: _add,
                        tooltip: '记录',
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: AppDimens.chipGap),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppDimens.chipGap),
                        itemBuilder: (_, i) => ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(suggestions[i]),
                          onPressed: () => _useSuggestion(suggestions[i]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 今日概览：大数字 + 进度条 + 三项营养。
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.totals, required this.target});

  final CalorieTotals totals;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consumed = totals.kcalInt;
    final ratio = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final over = target > 0 && consumed > target;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.chipGap,
        AppDimens.pagePadding,
        0,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$consumed',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: over ? AppColors.danger : AppColors.success,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    ' / $target kcal',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  over ? '超出 ${consumed - target}' : '还剩 ${target - consumed}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: over ? AppColors.danger : AppColors.todo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.chipGap),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.chipGap),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: over ? AppColors.danger : AppColors.success,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: AppDimens.cardGap),
            Row(
              children: [
                _Macro(label: '蛋白', grams: totals.proteinG, color: AppColors.active),
                _Macro(label: '碳水', grams: totals.carbG, color: AppColors.warning),
                _Macro(label: '脂肪', grams: totals.fatG, color: AppColors.danger),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams, required this.color});

  final String label;
  final double grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            '${grams.round()} g',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealHeader extends StatelessWidget {
  const _MealHeader({required this.group});

  final MealGroup group;

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
            group.meal.label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppDimens.chipGap),
          Text(
            '${group.subtotal.kcalInt} kcal',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onDelete});

  final CalorieEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey('calorie-${entry.id}'),
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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.pagePadding,
            vertical: AppDimens.cardGap,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Text(
                '${entry.kcal} kcal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
