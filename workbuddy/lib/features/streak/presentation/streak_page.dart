import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/streak.dart';
import '../providers/streak_providers.dart';

/// ============================================================================
/// 勋章页：火花数字 + 5 档勋章（已解锁金色亮起 / 未解锁灰锁 + 还差 X 天）
/// ============================================================================
///
/// 数据唯一来源是 [streakProvider]（从 `task_instances` 现算）。
/// 页面本身不缓存任何数字 —— 否则这里显示 7、主页显示 6 就说不清了。
class StreakPage extends ConsumerWidget {
  const StreakPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(streakProvider);
    final summary = async.value ?? StreakSummary.empty;

    // 历史最长取 max(现算, 缓存)：缓存是只增不减的下界，见 AppSettings.longestStreak。
    final cached = ref.watch(appSettingsProvider).longestStreak;
    final longest = summary.longestDays > cached ? summary.longestDays : cached;

    return Scaffold(
      appBar: AppBar(title: const Text('火花与勋章')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
        children: [
          _StreakHero(summary: summary, longest: longest),
          if (async.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding,
              ),
              child: Text(
                '火花读取失败：${async.error}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ),
          AppSectionHeader(
            '勋章',
            subtitle: '连续完成天数达到门槛即解锁，共 ${kStreakBadges.length} 枚',
          ),
          AppCard.group(
            children: [
              for (final badge in kStreakBadges)
                _BadgeTile(badge: badge, currentDays: summary.currentDays),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.sectionGap,
              AppDimens.pagePadding,
              0,
            ),
            child: Text(
              '火花按「当天完成至少 1 个任务」计数。当天还没结束时不会扣减 —— '
              '今天没做完，昨天的连续记录仍在，明天零点前补上就能接上。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部大卡：当前火花 + 历史最长 + 今日状态。
class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.summary, required this.longest});

  final StreakSummary summary;
  final int longest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = summary.currentDays > 0;

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.cardPadding * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.streak.withValues(
                    alpha: active ? 0.16 : 0.08,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  active
                      ? Icons.local_fire_department_rounded
                      : Icons.local_fire_department_outlined,
                  size: 32,
                  color: active
                      ? AppColors.streak
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppDimens.cardGap * 1.5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前火花',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${summary.currentDays}',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AppColors.streak
                              : theme.colorScheme.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('天', style: theme.textTheme.titleSmall),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '历史最长',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('$longest 天', style: theme.textTheme.titleMedium),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardGap),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.cardGap,
              vertical: AppDimens.chipGap + 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(AppDimens.chipGap),
            ),
            child: Row(
              children: [
                Icon(
                  summary.doneToday
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  size: 16,
                  color: summary.doneToday
                      ? AppColors.success
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _todayLabel(summary),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _todayLabel(StreakSummary summary) {
    if (summary.doneToday) {
      return '今天已完成任务，火花已到手';
    }
    if (summary.currentDays > 0) {
      return '今天还没完成任务 —— 今天结束前完成 1 个就能接上';
    }
    return '今天还没有完成任务，完成 1 个即可点亮火花';
  }
}

/// 单枚勋章：已解锁金杯 / 未解锁灰锁 + 还差 X 天。
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.currentDays});

  final StreakBadge badge;
  final int currentDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = currentDays >= badge.days;
    final remaining = badge.days - currentDays;
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListTile(
      // 解锁态不是「可点控件」，所以不给 onTap —— 不做点了没反应的假交互。
      leading: SizedBox(
        width: AppDimens.leadingIconWidth,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (unlocked ? AppColors.gold : muted).withValues(
                alpha: unlocked ? 0.16 : 0.10,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              unlocked
                  ? Icons.emoji_events_rounded
                  : Icons.lock_outline_rounded,
              size: 18,
              color: unlocked ? AppColors.gold : muted,
            ),
          ),
        ),
      ),
      title: Text(
        badge.name,
        style: TextStyle(
          color: unlocked ? theme.colorScheme.onSurface : muted,
          fontWeight: unlocked ? FontWeight.w600 : null,
        ),
      ),
      subtitle: Text(
        unlocked ? '已解锁 · ${badge.description}' : '还差 $remaining 天',
        style: TextStyle(color: unlocked ? AppColors.gold : muted),
      ),
      trailing: Text(
        '${badge.days} 天',
        style: theme.textTheme.labelSmall?.copyWith(
          color: unlocked ? AppColors.gold : muted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
