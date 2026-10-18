import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/location_reminder.dart';
import '../providers/location_providers.dart';

/// 全局监听「途径提醒触发」，在前台再弹一次 SnackBar。
///
/// 为什么放在 App 根部：触发发生在轮询器里（没有 context），
/// 而 SnackBar 需要一个 ScaffoldMessenger —— 由这个组件订阅流再弹，
/// 避免把 context 传进后台逻辑。
class LocationTriggerListener extends ConsumerStatefulWidget {
  const LocationTriggerListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LocationTriggerListener> createState() =>
      _LocationTriggerListenerState();
}

class _LocationTriggerListenerState
    extends ConsumerState<LocationTriggerListener> {
  StreamSubscription<LocationTrigger>? _sub;

  @override
  void initState() {
    super.initState();
    // 读 provider 会顺带启动轮询（见 locationWatcherProvider）
    _sub = ref.read(locationWatcherProvider).triggers.listen((trigger) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${trigger.message}（${trigger.reminder.title}）'),
            duration: const Duration(seconds: 5),
          ),
        );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
