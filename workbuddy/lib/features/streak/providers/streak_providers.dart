import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/time/day_tick.dart';
import '../data/streak_repository_impl.dart';
import '../domain/streak.dart';

/// 火花数据源。
final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  return StreakRepositoryImpl(ref.watch(databaseProvider));
});

/// 「今天」的零点，跨零点会自动推进。
///
/// 实现搬到了 `core/time/day_tick.dart`（任务列表也要用同一条节拍，
/// 否则「火花换了天、任务页还停在昨天」）。这里**直接别名**而不是再包一层，
/// 保持既有 override（测试）与依赖关系完全不变。
final streakTodayProvider = dayTickProvider;

/// 当前火花（响应式）。
///
/// 数据来自 `task_instances`，**不额外建表**；任何实例状态变化都会触发重算，
/// 用户点完成 → 数字当场 +1。
final streakProvider = StreamProvider<StreakSummary>((ref) {
  final repo = ref.watch(streakRepositoryProvider);
  final today =
      ref.watch(streakTodayProvider).value ?? streakDateOnly(DateTime.now());

  return repo.watchCompletedDays().map((days) {
    final summary = computeStreak(doneDays: days, now: today);
    _cacheLongest(ref, summary.longestDays);
    return summary;
  });
});

/// 把「历史最长」写进 app_settings（只增不减）。
///
/// 注意这里用的是 `ref.read` 而不是 `watch`：写入设置会让 settings 状态变化，
/// 若本 Provider 依赖它就会「写 → 重建 → 再算 → 再写」自己打自己。
/// 读一次当前值、只在被打破时写，天然幂等。
void _cacheLongest(Ref ref, int longest) {
  if (longest <= 0) return;
  if (longest <= ref.read(appSettingsProvider).longestStreak) return;
  unawaited(
    ref.read(appSettingsProvider.notifier).patch(longestStreak: longest),
  );
}
