import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../task/providers/task_providers.dart';
import '../providers/today_widget_providers.dart';

/// ============================================================================
/// 小组件数据同步的触发器（挂在 App 根部）
/// ============================================================================
///
/// 为什么放在根部、而不是在「完成任务」按钮里各调一次：
/// 改任务状态的入口有 6 个（开始/暂停/继续/完成/取消完成/删除），
/// 逐个插入同步调用必然漏一个。这里订阅**今日实例流**，
/// 数据库一变（不管是谁改的）就同步一次，天然覆盖所有入口。
///
/// 另外两条触发时机：
/// - 冷启动第一帧（桌面上的小组件要立刻反映当前数据）；
/// - 回到前台（后台期间数据可能被闹钟回调 / 定时任务改过，
///   Flutter 侧不一定收到事件）。
class TodayWidgetListener extends ConsumerStatefulWidget {
  const TodayWidgetListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TodayWidgetListener> createState() =>
      _TodayWidgetListenerState();
}

class _TodayWidgetListenerState extends ConsumerState<TodayWidgetListener>
    with WidgetsBindingObserver {
  /// 合并抖动：批量操作（连点完成、backfill 补 10 条）会连发多次
  /// 数据库变更，没必要每次都写一遍 SharedPreferences + 广播刷新。
  static const Duration _debounceDelay = Duration(milliseconds: 600);

  Timer? _timer;

  /// 正在同步时又收到变更 → 记一个「待补一次」，避免丢最后一次更新。
  bool _running = false;
  bool _pendingAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 首帧之后再同步：此时 ProviderScope 已就绪，数据库也已打开。
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule(delay: Duration.zero);
  }

  void _schedule({Duration? delay}) {
    if (!mounted) return;
    _timer?.cancel();
    _timer = Timer(delay ?? _debounceDelay, _run);
  }

  Future<void> _run() async {
    if (!mounted) return;
    if (_running) {
      _pendingAgain = true;
      return;
    }
    _running = true;
    try {
      await ref.read(todayWidgetSyncProvider).sync();
    } finally {
      _running = false;
      if (_pendingAgain && mounted) {
        _pendingAgain = false;
        _schedule();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 今日实例流一变就同步（已完成沉底重排也算一次变更，正好把数字刷新）。
    ref.listen(todayInstancesProvider, (previous, next) {
      if (next.hasValue) _schedule();
    });
    return widget.child;
  }
}
