import '../domain/task_enums.dart';
import '../domain/task_template.dart';

/// 惰性补齐算法（T01 规格 §3、§4）
///
/// 纯 Dart、零 Flutter / 零 Drift 依赖（规格 10.3），可脱离数据库单测。
/// 这是本模块的核心设计决策：
/// - **不用 WorkManager 定时生成**（国产 ROM 不可靠，且会漏掉未打开的天数）；
/// - 应用启动 / 回前台时按 `occurrenceDate` 逐日补齐缺失实例；
/// - 幂等性由数据库 `UNIQUE(templateId, occurrenceDate)` 保障（红线 3）。
///
/// 数据访问通过 [BackfillStore] 抽象接口注入（依赖倒置），
/// 由 Data 层（Drift）实现真实读写；测试可用内存实现。

/// 惰性补齐所需的数据访问抽象（Engine 只依赖本接口，零数据库依赖）
abstract interface class BackfillStore {
  /// 取全部未归档模板（archivedAt IS NULL）
  Future<List<TaskTemplate>> loadActiveTemplates();

  /// 某模板已生成的最大实例日期（MAX(occurrenceDate)），无则 null
  Future<DateTime?> lastGeneratedDate(int templateId);

  /// 幂等写入：已存在则原样返回（绝不能覆盖计时/完成状态），
  /// 不存在则插入快照 + status=todo + accumulatedSeconds=0。
  /// 返回 true 表示本次实际插入（便于测试断言）。
  Future<bool> upsertInstance(TaskTemplate template, DateTime date);
}

/// 单次最多回补的天数上限（规格 §4.4 / §六：产品决策未拍板，暂取建议值 30）
///
/// 防止「模板 startDate 是很久以前」时一次生成上千条实例导致首次启动卡顿。
/// 产品确认后可在 settings 中改为可配置。
const int kMaxBackfillDays = 30;

/// 判断模板在指定日期是否应当出现（规格 §4.2）
///
/// 注意周几语义（规格 §四）：Dart 的 `DateTime.weekday` 是 1=周一…7=周日，
/// **禁止**使用 Java `Calendar.DAY_OF_WEEK`（1=周日）语义（红线 6）。
bool matchesRepeatRule(TaskTemplate template, DateTime date) {
  switch (template.repeatMode) {
    case RepeatRule.once:
      // 单次任务仅在 startDate 当天出现
      return _sameDay(date, template.startDate);
    case RepeatRule.daily:
      // 每日重复：范围已由 startDate / endDate 控制
      return true;
    case RepeatRule.weekly:
      // 固定日重复：repeatDays 为空则恒 false（不抛异常）
      if (template.repeatDays.isEmpty) return false;
      // 1=周一 … 7=周日（Dart 语义）
      return template.repeatDays.contains(date.weekday);
  }
}

/// 惰性补齐主流程（规格 §4.1）
///
/// ```
/// templates = 未归档模板
/// for each tpl:
///   from = lastGeneratedDate(tpl) ?? tpl.startDate
///   from = max(from, today - MAX_BACKFILL_DAYS)
///   from = max(from, tpl.startDate)
///   date = from
///   while date <= today:
///     if tpl.endDate != null && date > tpl.endDate: break
///     if matchesRepeatRule(tpl, date): upsertInstance(tpl, date)
///     date += 1 day
/// ```
Future<void> backfillOnAppStart(
  BackfillStore store,
  DateTime today, {
  int maxBackfillDays = kMaxBackfillDays,
}) async {
  final templates = await store.loadActiveTemplates();

  for (final tpl in templates) {
    // from = lastGeneratedDate(tpl) ?? startDate
    var from = await store.lastGeneratedDate(tpl.id ?? -1);
    if (from == null) from = _dayStart(tpl.startDate);

    // from = max(from, today - MAX_BACKFILL_DAYS)
    // 注意：规格 §4.1 伪代码写 today - MAX，但 D8 断言「实例数 ≤ MAX_BACKFILL_DAYS」，
    // 含 today 在内最多补 MAX 天 → 用 (today - (MAX-1))，避免多出一天违反断言。
    final cutoff = today.subtract(Duration(days: maxBackfillDays - 1));
    if (from.isBefore(cutoff)) from = cutoff;

    // from = max(from, tpl.startDate) —— 规格 §4.1 第 3 行
    // startDate 归一化到当天 0 点，避免带时分秒时 from > today 导致漏补
    final startDay = _dayStart(tpl.startDate);
    if (from.isBefore(startDay)) from = startDay;

    var date = from;
    while (!date.isAfter(today)) {
      // endDate 之后不再生成（U5 用例）
      final end = tpl.endDate;
      if (end != null && date.isAfter(end)) break;
      if (matchesRepeatRule(tpl, date)) {
        await store.upsertInstance(tpl, date);
      }
      date = date.add(const Duration(days: 1));
    }
  }
}

/// 比较两个 DateTime 是否为同一天（忽略时分秒）
bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 归一化到当天 0 点（本地时区）
DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
