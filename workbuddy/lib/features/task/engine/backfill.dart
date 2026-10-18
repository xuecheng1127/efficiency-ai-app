import '../domain/task_enums.dart';
import '../domain/task_template.dart';

/// 惰性补齐上限（天）。防止模板 startDate 是很久以前时一次生成上千条实例。
/// 建议 30 天（见 T01 规格 §6.1）。
const int maxBackfillDays = 30;

/// 取「日期」（去掉时间部分），统一用本地日期做比较。
DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// 判断某日期是否应生成实例（范围 + 重复规则，纯逻辑，可单测）。
///
/// 周几语义：Dart 的 `DateTime.weekday` 是 1=周一 … 7=周日，
/// 禁止使用 `Calendar.DAY_OF_WEEK`（1=周日）的语义。
bool matchesRepeatRule({
  required RepeatMode repeatMode,
  required List<int> repeatDays,
  required DateTime startDate,
  DateTime? endDate,
  required DateTime date,
}) {
  final d = dateOnly(date);
  final s = dateOnly(startDate);

  // 范围：startDate 之前 / endDate 之后均不生成
  if (d.isBefore(s)) return false;
  if (endDate != null && d.isAfter(dateOnly(endDate))) return false;

  switch (repeatMode) {
    case RepeatMode.once:
      return d.isAtSameMomentAs(s);
    case RepeatMode.daily:
      return true;
    case RepeatMode.weekly:
      return repeatDays.isNotEmpty && repeatDays.contains(d.weekday);
  }
}

/// 数据源抽象（依赖倒置）：backfill 算法不直接依赖 Drift，
/// 由 Data 层提供实现，从而可对算法做纯 Dart 单元测试。
abstract interface class BackfillDataSource {
  /// 所有未归档模板。
  Future<List<TaskTemplate>> getActiveTemplates();

  /// 某模板已生成实例的最大 occurrenceDate（无则 null）。
  Future<DateTime?> lastOccurrenceDate(int templateId);

  /// 幂等写入实例：已存在（含软删除）则不动，否则插入（禁止覆盖，见规格 §11 禁止清单第 2 条）。
  Future<void> upsertInstance(TaskTemplate template, DateTime date);
}

/// 惰性补齐：为每个模板补齐 [today] 及之前缺失的实例。
///
/// 设计决策（见 T01 规格 §3）：
/// - 惰性补齐而非 WorkManager 定时：国产 ROM 上后台任务不可靠，且定时会漏掉未打开的天数。
/// - 幂等：靠 `UNIQUE(templateId, occurrenceDate)`，重复执行不产生重复数据。
Future<void> backfill(BackfillDataSource source, DateTime today) async {
  final templates = await source.getActiveTemplates();
  final end = dateOnly(today);

  for (final tpl in templates) {
    var from =
        await source.lastOccurrenceDate(tpl.id) ?? dateOnly(tpl.startDate);
    from = dateOnly(from);

    // 上限保护：最多回补 maxBackfillDays 天（用 -1 保证恰好 ≤ maxBackfillDays 条）
    final minFrom = end.subtract(Duration(days: maxBackfillDays - 1));
    if (from.isBefore(minFrom)) from = minFrom;
    if (from.isBefore(dateOnly(tpl.startDate))) from = dateOnly(tpl.startDate);

    for (
      var date = from;
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      if (matchesRepeatRule(
        repeatMode: tpl.repeatMode,
        repeatDays: tpl.repeatDays,
        startDate: tpl.startDate,
        endDate: tpl.endDate,
        date: date,
      )) {
        await source.upsertInstance(tpl, date);
      }
    }
  }
}
