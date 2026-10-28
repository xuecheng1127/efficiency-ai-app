import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../providers/streak_providers.dart';
import 'streak_page.dart';

/// AppBar 右侧的火花入口：🔥 + 当前连续天数，点击进入勋章页。
///
/// 为什么不用 `IconButton`：它只放得下一个图标或一个数字，而需求要的是
/// 「🔥 + 数字」的组合。这里用 [InkWell] + Row 手动拼，点击热区仍有 44dp 高
/// （AppBar 内 `constraints` 会做最小尺寸约束）。
class StreakButton extends ConsumerWidget {
  const StreakButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(streakProvider).value;
    final days = summary?.currentDays ?? 0;
    final active = days > 0;

    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.chipGap),
      child: Tooltip(
        message: active ? '连续 $days 天完成 · 查看勋章' : '还没有火花 · 查看勋章',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const StreakPage())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 20,
                  // 0 天时不用橙色：灰色才不会让人误以为「已经有火花了」。
                  color: active
                      ? AppColors.streak
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  '$days',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    // tabular figures：数字变化时宽度不跳（1 → 10 不会推挤旁边图标）
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: active
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
