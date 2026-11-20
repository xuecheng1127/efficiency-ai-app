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

    void open() => Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const StreakPage()));

    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.chipGap),
      // R3：🔥 + 数字对读屏是一片「静默」——火苗是图标、数字没有上下文。
      // 这里补一句完整的话，并且 `excludeSemantics` 掉里面的图标与数字：
      // 否则它会念成「火焰 · 3」，用户还是不知道点进去是什么。
      child: Semantics(
        container: true,
        button: true,
        label: active ? '连续完成 $days 天，点击查看勋章' : '还没有连续完成记录，点击查看勋章',
        excludeSemantics: true,
        onTap: open,
        child: Tooltip(
          message: active ? '连续 $days 天完成 · 查看勋章' : '还没有火花 · 查看勋章',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: open,
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
      ),
    );
  }
}
