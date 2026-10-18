import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/birthday.dart';
import '../providers/birthday_providers.dart';
import 'birthday_edit_page.dart';

/// 朋友生日（工具箱插件 2）。
///
/// 列表口径：**按距离下一次生日的天数升序**；7 天内高亮；农历生日显示农历日期，
/// 闰月年份额外标注（避免"到底是九月还是闰九月"的疑问）。
class BirthdayListPage extends ConsumerWidget {
  const BirthdayListPage({super.key});

  Future<void> _openEditor(BuildContext context, {Birthday? existing}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BirthdayEditPage(existing: existing)),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BirthdayOccurrence occ,
  ) async {
    final repo = ref.read(birthdayRepositoryProvider);
    await repo.softDelete(occ.birthday.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已删除「${occ.birthday.name}」的生日'),
          action: SnackBarAction(
            label: '撤销',
            // 撤销 = 取消软删除；提醒会在下次保存/启动时重新排上
            onPressed: () => repo.restore(occ.birthday.id),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncList = ref.watch(birthdayListProvider);
    final upcoming = ref.watch(upcomingBirthdaysProvider);

    final Widget body;
    if (asyncList.hasError && !asyncList.hasValue) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '生日数据读取失败',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppDimens.sectionHeaderGap),
            FilledButton(
              onPressed: () => ref.invalidate(birthdayListProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    } else if (!asyncList.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (upcoming.isEmpty) {
      body = const EmptyState(
        icon: Icons.cake_outlined,
        title: '还没有记录生日',
        subtitle: '点右下角「添加生日」，支持公历和农历',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.only(
          top: AppDimens.sectionHeaderGap,
          bottom: AppDimens.sectionGap * 2,
        ),
        children: [
          AppSectionHeader(
            '接下来',
            subtitle: upcoming.first.isSoon
                ? '最近的是 ${upcoming.first.birthday.name}，${upcoming.first.countdownLabel}'
                : '按距离远近排序，7 天内会高亮',
          ),
          for (final occ in upcoming)
            _BirthdayCard(
              occ: occ,
              onTap: () => _openEditor(context, existing: occ.birthday),
              onDelete: () => _delete(context, ref, occ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('朋友生日')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('添加生日'),
      ),
      body: body,
    );
  }
}

class _BirthdayCard extends StatelessWidget {
  const _BirthdayCard({
    required this.occ,
    required this.onTap,
    required this.onDelete,
  });

  final BirthdayOccurrence occ;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = occ.birthday;
    final soon = occ.isSoon;

    return Dismissible(
      key: ValueKey('birthday-${b.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimens.pagePadding),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.pagePadding),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (soon ? AppColors.success : theme.colorScheme.primary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                    ),
                    child: Text(
                      b.name.isEmpty ? '?' : b.name.substring(0, 1),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: soon
                            ? AppColors.success
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.cardGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                b.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.chipGap),
                            _Tag(
                              text: b.calendar.label,
                              color: b.calendar == BirthdayCalendar.lunar
                                  ? AppColors.warning
                                  : theme.colorScheme.primary,
                            ),
                            if (occ.hasLeapMonth) ...[
                              const SizedBox(width: AppDimens.chipGap),
                              const _Tag(text: '闰月', color: AppColors.danger),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${occ.dateLabel} · ${b.groupLabel}'
                          '${occ.hasLeapMonth ? ' · 今年闰${b.month}月，按非闰月计算' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.chipGap),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        occ.countdownLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: soon
                              ? AppColors.success
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: soon ? FontWeight.w600 : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '提前 ${b.advanceDays} 天提醒',
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
      ),
    );
  }
}

/// 小标签（历法 / 闰月）。
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.chipGap),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
