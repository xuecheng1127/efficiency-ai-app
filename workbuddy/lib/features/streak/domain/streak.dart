/// ============================================================================
/// 火花（streak）领域计算 —— 纯函数，零 Flutter / 零数据库依赖
/// ============================================================================
///
/// 定义（严格对齐评审口径）：
/// - 火花 = 连续完成「自己列表里的任务」的天数；
/// - 当天完成 ≥1 个任务 → 火花 +1；当天 0 个完成 → 归零；
/// - **当天还没过完不扣**：不能因为「今天早上还没做」就把昨天攒的火花清零。
///
/// 第三条是这里唯一容易写错的语义，落成代码就是一句话：
/// 起点选「今天（如果今天已有完成）」否则「昨天」，然后向前逐日回退。
/// 只要昨天有完成，今天没做也照样从昨天开始数 —— 不扣。
library;

/// 归一化到本地日期的零点。
///
/// 用 `DateTime(y, m, d)` 而不是 `subtract(Duration(days: 1))`：
/// 后者在夏令时切换日会得到 23 或 25 小时，跨时区/换季时可能少算或重算一天。
DateTime streakDateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// 前一天（按日历，不是按 24 小时）。
DateTime previousStreakDay(DateTime day) =>
    DateTime(day.year, day.month, day.day - 1);

/// 火花汇总。
class StreakSummary {
  const StreakSummary({
    required this.currentDays,
    required this.longestDays,
    required this.doneToday,
  });

  /// 当前连续天数（今天没做但昨天做了 → 仍然保留昨天的连续数）。
  final int currentDays;

  /// 历史最长连续天数（含当前这段）。
  final int longestDays;

  /// 今天是否已完成过至少 1 个任务。
  final bool doneToday;

  /// 空态：没有完成记录时的值。
  static const StreakSummary empty = StreakSummary(
    currentDays: 0,
    longestDays: 0,
    doneToday: false,
  );
}

/// 从「已完成日期集合」算出火花。
///
/// [doneDays] 允许含时分秒（内部会归一化），重复日期自动去重。
/// [now] 传进来而不是内部取 `DateTime.now()`，测试才能固定时间。
StreakSummary computeStreak({
  required Iterable<DateTime> doneDays,
  required DateTime now,
}) {
  final today = streakDateOnly(now);

  // 只收「今天及以前」的日期：时钟被调到未来 / 数据被改坏时，
  // 未来日期不应污染统计（也避免 longest 里出现一段永远无法延续的记录）。
  final days = <DateTime>{
    for (final d in doneDays)
      if (!streakDateOnly(d).isAfter(today)) streakDateOnly(d),
  };

  final doneToday = days.contains(today);

  // 起点：今天做了就从今天数；今天还没做就从昨天数（**不扣当天**）。
  var cursor = doneToday ? today : previousStreakDay(today);
  var current = 0;
  while (days.contains(cursor)) {
    current++;
    cursor = previousStreakDay(cursor);
  }

  final longest = _longestRun(days);
  return StreakSummary(
    currentDays: current,
    // 当前这段理论上一定 ≤ longest，取 max 只是兜住「实现被改坏」的情况。
    longestDays: longest < current ? current : longest,
    doneToday: doneToday,
  );
}

/// 最长连续段（按日历排序后扫一遍）。
int _longestRun(Set<DateTime> days) {
  if (days.isEmpty) return 0;
  final sorted = days.toList()..sort();
  var longest = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final expected = DateTime(
      sorted[i - 1].year,
      sorted[i - 1].month,
      sorted[i - 1].day + 1,
    );
    if (sorted[i] == expected) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }
  return longest;
}

/// 勋章（火花天数门槛）。
class StreakBadge {
  const StreakBadge({
    required this.days,
    required this.name,
    required this.description,
  });

  final int days;
  final String name;
  final String description;
}

/// 五档勋章（顺序固定，勋章页按此顺序展示）。
const List<StreakBadge> kStreakBadges = [
  StreakBadge(days: 3, name: '初露锋芒', description: '连续 3 天完成任务'),
  StreakBadge(days: 7, name: '一周不断', description: '连续 7 天完成任务'),
  StreakBadge(days: 30, name: '月度坚持', description: '连续 30 天完成任务'),
  StreakBadge(days: 100, name: '百日筑基', description: '连续 100 天完成任务'),
  StreakBadge(days: 365, name: '全年无休', description: '连续 365 天完成任务'),
];

/// 已解锁的勋章（`currentDays >= days`）。
List<StreakBadge> unlockedBadges(int currentDays) => [
  for (final b in kStreakBadges)
    if (currentDays >= b.days) b,
];

/// 下一枚待解锁勋章；全部解锁返回 null。
StreakBadge? nextBadge(int currentDays) {
  for (final b in kStreakBadges) {
    if (currentDays < b.days) return b;
  }
  return null;
}
