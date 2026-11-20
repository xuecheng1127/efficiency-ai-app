import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/geofence_pulse.dart';
import '../providers/location_providers.dart';

/// ============================================================================
/// 途径提醒的根组件：**把「监测总开关」挂到 App 生命周期上**
/// ============================================================================
///
/// 三件事，都在根部做（不在某个页面里）：
///
/// 1. App 启动 → `monitor.sync()`：有启用中的围栏就起前台服务，
///    没有就什么都不做（不留常驻通知、不空转耗电）；
/// 2. 提醒增删改（`locationRemindersProvider` 变了）→ 重新 sync：
///    新增/启用 → 起服务；全禁用/删除 → 停服务；
/// 3. 从后台回到前台 → 再 sync 一次：
///    用户可能在系统设置里改了权限、也可能划掉了常驻通知，
///    回到 App 必须重新对齐「实际在跑的到底是什么」。
class LocationTriggerListener extends ConsumerStatefulWidget {
  const LocationTriggerListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LocationTriggerListener> createState() =>
      _LocationTriggerListenerState();
}

class _LocationTriggerListenerState
    extends ConsumerState<LocationTriggerListener>
    with WidgetsBindingObserver {
  ProviderSubscription<AsyncValue<List<Object?>>>? _remindersSub;
  StreamSubscription<LocationAlert>? _alertSub;
  bool _syncing = false;
  bool _syncQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 读 provider 会创建 monitor（插件初始化 + 状态对齐）
    final monitor = ref.read(locationMonitorProvider);
    _alertSub = monitor.alerts.listen(_show);

    // 提醒列表变化 → 重新对齐（listenManual 不需要 build 上下文）
    _remindersSub = ref.listenManual(locationRemindersProvider, (_, _) {
      unawaited(_sync());
    });

    unawaited(_sync());
  }

  /// 串行化：同一时刻只跑一次 sync，期间再来请求就排队跑最后一次。
  ///
  /// 为什么需要：一次 sync 要跨 3 个异步边界（prefs / 数据库 / 插件通道），
  /// 而「App 启动 + 列表首帧 + 恢复前台」常常同时触发，
  /// 并发跑会把 `startService` 撞成 `ServiceAlreadyStartedException`。
  Future<void> _sync() async {
    if (_syncing) {
      _syncQueued = true;
      return;
    }
    _syncing = true;
    try {
      await ref.read(locationMonitorProvider).sync();
    } catch (_) {
      // 后台监测是增强能力：失败不该影响 App 正常使用
    } finally {
      _syncing = false;
      if (_syncQueued) {
        _syncQueued = false;
        unawaited(_sync());
      }
    }
  }

  void _show(LocationAlert alert) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${alert.message}（${alert.title}）'),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _remindersSub?.close();
    _alertSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
