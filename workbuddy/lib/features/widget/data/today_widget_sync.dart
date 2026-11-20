import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../task/domain/task_repository.dart';
import '../application/today_widget_data.dart';

/// 小组件同步日志（`adb logcat -d | findstr home-widget` 可直接过滤）。
const String widgetLogTag = '[R2][home-widget]';

void widgetLog(String message) {
  debugPrint('$widgetLogTag $message');
}

/// Android 端 `AppWidgetProvider` 的**全限定类名**。
///
/// 必须与 `TodayTasksWidgetProvider.kt` 的包名一致；用全限定名而不是短名，
/// 是因为 `home_widget` 的短名解析依赖「applicationId + 类名」的拼接规则，
/// 一旦 applicationId 与 namespace 不一致就会静默找不到 provider。
const String kTodayTasksWidgetProvider =
    'com.efficiency.app.efficiency_app.widget.TodayTasksWidgetProvider';

/// 「添加到桌面」的结果（UI 用它决定说哪句话）。
enum WidgetPinResult {
  /// 系统已经弹出添加确认框（用户还需要在弹框里点「添加」）。
  requested,

  /// 这个桌面不支持 `requestPinAppWidget`（少数第三方桌面 / 老系统）。
  unsupported,

  /// 调起过程抛错（通道异常等）。
  failed,
}

/// 请求把「今日任务」固定到桌面（Android 8.0+）。
///
/// 为什么应用不能自己把组件塞上去：AppWidget 的宿主是**桌面进程**，
/// 只有桌面能 `allocateAppWidgetId` 并绑定视图。应用能做的是
/// `requestPinAppWidget`——让桌面弹一个「要添加吗」的确认框，用户点一下才生效。
///
/// 两个入口是同一件事：桌面长按 → 小组件 → 今日任务，或者本方法。
/// 后者对用户更短（不用在几百个组件里找自己那个 App）。
Future<WidgetPinResult> requestPinTodayWidget() async {
  if (!Platform.isAndroid) return WidgetPinResult.unsupported;
  try {
    final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (!supported) {
      widgetLog('requestPin: launcher does not support pinning');
      return WidgetPinResult.unsupported;
    }
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: kTodayTasksWidgetProvider,
    );
    widgetLog('requestPin: dialog requested');
    return WidgetPinResult.requested;
  } catch (e) {
    widgetLog('requestPin failed: $e');
    return WidgetPinResult.failed;
  }
}

/// SharedPreferences 里的键（与 Kotlin 侧逐字对应，改名必须两边一起改）。
abstract final class TodayWidgetKeys {
  static const String date = 'today_date';
  static const String done = 'today_done';
  static const String total = 'today_total';
  static const String remaining = 'today_remaining';
  static const String emptyLabel = 'today_empty_label';
  static const String task1 = 'today_task_1';
  static const String task2 = 'today_task_2';
  static const String task3 = 'today_task_3';
}

/// ============================================================================
/// 把「今天的任务」推给桌面小组件
/// ============================================================================
///
/// 数据流：Drift（真源）→ 本类算一份快照 → `HomeWidget.saveWidgetData`
/// → `HomeWidget.updateWidget` 广播 → Kotlin `AppWidgetProvider` 读
/// SharedPreferences 渲染 RemoteViews。
///
/// 为什么**不**让小组件自己去读数据库：4x2 的 RemoteViews 在桌面进程里渲染，
/// 那里没有 Drift、没有迁移、也不该为一次刷新去开数据库连接；
/// Dart 侧算好 6 个标量写进 SharedPreferences，Kotlin 只负责排版。
class TodayWidgetSync {
  TodayWidgetSync(this._repository, {DateTime Function() clock = DateTime.now})
    : _clock = clock;

  final TaskRepository _repository;
  final DateTime Function() _clock;

  /// 最近一次同步是否成功（UI 排查用；失败不抛给调用方）。
  bool get lastSucceeded => _lastSucceeded;
  bool _lastSucceeded = false;

  /// 同步一次。**永不抛异常**：小组件是锦上添花，
  /// 不能因为它失败就让任务页的操作报错。
  Future<bool> sync() async {
    // 只有 Android 有 AppWidget；其余平台直接跳过（也避免测试里抛 MissingPlugin）。
    if (!Platform.isAndroid) return false;

    try {
      final now = _clock();
      final day = DateTime(now.year, now.month, now.day);

      // 跨天/首次安装时，今天的实例可能还没生成 —— 先补齐再统计，
      // 否则小组件会显示「今天没有任务」，而 App 里明明有。
      await _repository.backfill(day);

      final instances = await _repository
          .watchTodayInstances(day)
          .first
          .timeout(const Duration(seconds: 5));

      final data = buildTodayWidgetData(instances, now);

      await HomeWidget.saveWidgetData<String>(
        TodayWidgetKeys.date,
        data.dateLabel,
      );
      await HomeWidget.saveWidgetData<int>(TodayWidgetKeys.done, data.done);
      await HomeWidget.saveWidgetData<int>(TodayWidgetKeys.total, data.total);
      await HomeWidget.saveWidgetData<int>(
        TodayWidgetKeys.remaining,
        data.remaining,
      );
      await HomeWidget.saveWidgetData<String>(
        TodayWidgetKeys.emptyLabel,
        data.emptyLabel,
      );
      await HomeWidget.saveWidgetData<String>(
        TodayWidgetKeys.task1,
        data.numberedTitleAt(0),
      );
      await HomeWidget.saveWidgetData<String>(
        TodayWidgetKeys.task2,
        data.numberedTitleAt(1),
      );
      await HomeWidget.saveWidgetData<String>(
        TodayWidgetKeys.task3,
        data.numberedTitleAt(2),
      );

      final updated = await HomeWidget.updateWidget(
        qualifiedAndroidName: kTodayTasksWidgetProvider,
      );

      _lastSucceeded = updated ?? false;
      widgetLog(
        'sync ok: ${data.progressLabel}, pending=${data.remaining}, '
        'updated=$updated',
      );
      return _lastSucceeded;
    } catch (e) {
      _lastSucceeded = false;
      // 明确记录而不是静默 return：小组件不刷新是最容易被当成「坏了」的问题。
      widgetLog('sync failed: $e');
      return false;
    }
  }
}
