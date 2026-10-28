import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/settings/app_settings.dart';
import '../data/streak_repository_impl.dart';
import '../domain/streak.dart';

/// 火花数据源。
final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  return StreakRepositoryImpl(ref.watch(databaseProvider));
});

/// 「今天」的零点，跨零点会自动推进。
///
/// 为什么单独抽一个 Provider：火花的定义依赖「今天是哪天」，
/// 如果只在页面 build 时取一次 `DateTime.now()`，应用挂后台过夜后
/// 火花的「今天没做不扣」会算错一天。这里用一条到次日零点自动醒来的流，
/// 跨日时下游（streakProvider）自然重算。
final streakTodayProvider = StreamProvider<DateTime>((ref) async* {
  while (true) {
    final now = DateTime.now();
    final today = streakDateOnly(now);
    yield today;
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // +1 秒：确保醒来时已经跨过零点（否则可能落在 23:59:59.999）。
    await Future<void>.delayed(
      nextMidnight.difference(now) + const Duration(seconds: 1),
    );
  }
});

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
