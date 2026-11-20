import '../../task/domain/task_enums.dart';
import '../../task/domain/task_instance.dart';

/// ============================================================================
/// 桌面小组件要展示的「今日概览」
/// ============================================================================
///
/// 抽成纯函数 + 不可变值对象（不碰 HomeWidget、不碰 Android）：
/// 单测能直接喂一批 [TaskInstance] 断言「完成数 / 前三条 / 空态文案」，
/// 不需要模拟器、也不需要真的桌面。
class TodayWidgetData {
  const TodayWidgetData({
    required this.dateLabel,
    required this.done,
    required this.total,
    required this.pendingTitles,
    required this.remaining,
  });

  /// 小组件里最多列几条未完成任务（4x2 的物理高度只够三行）。
  static const int maxPending = 3;

  static const List<String> _weekdays = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  /// `11月19日 · 周四`
  final String dateLabel;

  final int done;
  final int total;

  /// 前 [maxPending] 条未完成任务的标题（不足则少几条）。
  final List<String> pendingTitles;

  /// 未完成总数（可能 > [pendingTitles].length）：空态文案要用它。
  final int remaining;

  /// `已完成 2 / 5`
  String get progressLabel => '已完成 $done / $total';

  /// 进度条百分比（0–100，整数）。总数为 0 时按 0 处理。
  int get progressPercent => total == 0 ? 0 : (done * 100 ~/ total);

  /// 三行任务的占位文本：没有对应任务时是空串（Kotlin 侧据此隐藏那一行）。
  String titleAt(int index) =>
      index < pendingTitles.length ? pendingTitles[index] : '';

  /// 空态文案（三条都空时才显示）。
  String get emptyLabel => total == 0 ? '今天没有任务' : '今天的任务都完成了';

  /// 把编号写成「1. xxx」——小组件里没有序号列，前缀是最省空间的编号方式。
  String numberedTitleAt(int index) {
    final t = titleAt(index);
    return t.isEmpty ? '' : '${index + 1}. $t';
  }

  static String dateLabelOf(DateTime now) =>
      '${now.month}月${now.day}日 · ${_weekdays[now.weekday - 1]}';
}

/// 今日实例 → 小组件数据。
///
/// 只统计**未删除**的实例（仓库已经在 SQL 里过滤过，这里再兜一次底：
/// 别的调用方可能传进来一份未过滤的列表）。
TodayWidgetData buildTodayWidgetData(
  List<TaskInstance> instances,
  DateTime now,
) {
  final alive = instances.where((i) => i.deletedAt == null).toList();

  final done = alive.where((i) => i.status == TaskStatus.done).length;
  final pending = alive.where((i) => i.status != TaskStatus.done).toList();

  return TodayWidgetData(
    dateLabel: TodayWidgetData.dateLabelOf(now),
    done: done,
    total: alive.length,
    pendingTitles: pending
        .take(TodayWidgetData.maxPending)
        .map((i) => i.titleSnapshot)
        .toList(),
    remaining: pending.length,
  );
}
