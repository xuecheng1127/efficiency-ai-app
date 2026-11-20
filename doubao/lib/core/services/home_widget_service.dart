import 'package:home_widget/home_widget.dart';

import '../../features/task/domain/task_enums.dart';
import '../../features/task/domain/task_repository.dart';

/// 桌面小组件（今日任务）同步服务（R3）
///
/// 把今日任务的完成进度与前 3 条未完成标题写入 home_widget 存储，
/// 再通知原生 Provider 刷新。小组件是增强能力：任何同步/通道异常都静默吞掉，
/// 不阻断主流程。
class HomeWidgetService {
  HomeWidgetService._();

  /// Provider 全限定类名（与 Android 端 TodayWidgetProvider 一致）
  static const _provider = 'com.efficiency.app.widget.TodayWidgetProvider';

  static const _kDate = 'widget_date';
  static const _kDone = 'widget_done';
  static const _kTotal = 'widget_total';
  static const _kTask1 = 'widget_task_1';
  static const _kTask2 = 'widget_task_2';
  static const _kTask3 = 'widget_task_3';
  static const _kOpenCount = 'widget_open_count';

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  /// 由今日任务列表生成小组件快照（纯函数，便于单测）
  static WidgetSnapshot buildSnapshot(
    List<TaskWithOccurrence> tasks, {
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final dateLabel =
        '${date.month}月${date.day}日 周${_weekdays[date.weekday - 1]}';

    var done = 0;
    final openTitles = <String>[];
    for (final item in tasks) {
      if (item.occurrence.status == TaskStatus.done) {
        done++;
      } else {
        final title = item.occurrence.titleSnapshot.trim();
        if (title.isNotEmpty) openTitles.add(title);
      }
    }

    return WidgetSnapshot(
      dateLabel: dateLabel,
      done: done,
      total: tasks.length,
      openTitles: openTitles.take(3).toList(),
      openCount: openTitles.length,
    );
  }

  /// 用今日任务列表刷新小组件
  static Future<void> syncTodayTasks(List<TaskWithOccurrence> tasks) async {
    try {
      final snapshot = buildSnapshot(tasks);

      await HomeWidget.saveWidgetData<String>(_kDate, snapshot.dateLabel);
      await HomeWidget.saveWidgetData<int>(_kDone, snapshot.done);
      await HomeWidget.saveWidgetData<int>(_kTotal, snapshot.total);
      await HomeWidget.saveWidgetData<String>(
          _kTask1, snapshot.openTitles.isNotEmpty ? snapshot.openTitles[0] : '');
      await HomeWidget.saveWidgetData<String>(
          _kTask2, snapshot.openTitles.length > 1 ? snapshot.openTitles[1] : '');
      await HomeWidget.saveWidgetData<String>(
          _kTask3, snapshot.openTitles.length > 2 ? snapshot.openTitles[2] : '');
      await HomeWidget.saveWidgetData<int>(_kOpenCount, snapshot.openCount);

      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (_) {
      // 小组件同步失败不影响 App 主流程
    }
  }
}

/// 小组件快照值对象（纯数据，无平台依赖）
class WidgetSnapshot {
  final String dateLabel;
  final int done;
  final int total;

  /// 前 3 条未完成标题（超出 3 条截断）
  final List<String> openTitles;

  /// 未完成总数（用于空态判断，不受前 3 条截断影响）
  final int openCount;

  const WidgetSnapshot({
    required this.dateLabel,
    required this.done,
    required this.total,
    required this.openTitles,
    required this.openCount,
  });
}
