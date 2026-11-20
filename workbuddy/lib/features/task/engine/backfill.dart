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

/// 一条「需要写入的实例」：算法只产出这个纯数据，不碰任何 ORM 类型。
class BackfillDraft {
  const BackfillDraft({required this.template, required this.date});

  final TaskTemplate template;
  final DateTime date;
}

/// 数据源抽象（依赖倒置）：backfill 算法不直接依赖 Drift，
/// 由 Data 层提供实现，从而可对算法做纯 Dart 单元测试。
///
/// **批量接口（R5）**：旧版是「每个模板一次 `lastOccurrenceDate` + 每个日期一次
/// `upsertInstance`」，1000 个模板就是 2000+ 次跨 isolate 查询，实测冷启动多花
/// 3.1 秒（见 R5 报告）。现在整轮只发 2 条 SQL：一条分组取 max，一条批量插入。
abstract interface class BackfillDataSource {
  /// 所有未归档模板。
  Future<List<TaskTemplate>> getActiveTemplates();

  /// 批量取「每个模板已有的最大 occurrenceDate」（没有实例的模板不出现在 map 里）。
  ///
  /// 一条 `GROUP BY template_id, MAX(occurrence_date)` 就能拿到全部，
  /// 不再按模板逐个查询。
  Future<Map<int, DateTime>> lastOccurrenceDates();

  /// 批量写入缺失实例（幂等：靠 `UNIQUE(templateId, occurrenceDate)` 忽略冲突，
  /// 不会覆盖用户已有的计时/完成状态）。
  Future<void> insertInstances(List<BackfillDraft> drafts);
}

/// 惰性补齐：为每个模板补齐 [today] 及之前缺失的实例。
///
/// 设计决策（见 T01 规格 §3）：
/// - 惰性补齐而非 WorkManager 定时：国产 ROM 上后台任务不可靠，且定时会漏掉未打开的天数。
/// - 幂等：靠 `UNIQUE(templateId, occurrenceDate)`，重复执行不产生重复数据。
/// - **两轮 IO（R5）**：先「取模板 + 取各自最大日期」，其余判断与日期推进全在内存里算，
///   最后一次性批量插入。没有缺失时一条 INSERT 都不发。
Future<void> backfill(BackfillDataSource source, DateTime today) async {
  final templates = await source.getActiveTemplates();
  if (templates.isEmpty) return; // 空库直接返回，省掉第二次查询
  final end = dateOnly(today);
  final lastByTemplate = await source.lastOccurrenceDates();

  final drafts = <BackfillDraft>[];
  for (final tpl in templates) {
    final lastDate = lastByTemplate[tpl.id];
    var from = dateOnly(lastDate ?? tpl.startDate);

    // 上限保护：最多回补 maxBackfillDays 天（用 -1 保证恰好 ≤ maxBackfillDays 条）
    final minFrom = end.subtract(Duration(days: maxBackfillDays - 1));
    if (from.isBefore(minFrom)) from = minFrom;
    if (from.isBefore(dateOnly(tpl.startDate))) from = dateOnly(tpl.startDate);

    // 旧实现从「已有最后一天」当天开始循环，再靠 upsert 的存在性检查把它空转掉。
    // 批量写入没法逐条判重（`insertOrIgnore` 会真的发一条被忽略的 INSERT），
    // 所以这里直接跳过那一天 —— 它按定义已存在。
    //
    // 只在「from 恰好就是那一天」时跳：如果 lastDate 早于回补窗口被 clamp 到
    // minFrom，那 minFrom 那天其实是缺的，不能跳。
    if (lastDate != null && from.isAtSameMomentAs(dateOnly(lastDate))) {
      from = from.add(const Duration(days: 1));
    }

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
        drafts.add(BackfillDraft(template: tpl, date: date));
      }
    }
  }

  // 全部命中（最常见的稳态）时直接收工
  if (drafts.isEmpty) return;
  await source.insertInstances(drafts);
}
