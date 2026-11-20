import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/startup_trace.dart';
import '../features/location/presentation/location_trigger_listener.dart';
import '../features/widget/presentation/today_widget_listener.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// 应用根组件：主题 + 路由装配。
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '效率',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      // 途径提醒触发时在前台再弹一次 SnackBar（后台时有系统通知兜底）
      //
      // 字号上限（R1 任务 3）：系统字号可以调到 2.0，但本 app 的卡片/图表/
      // 计时器是按 1.0 设计的，2.0 下「一行两个按钮 + 长文案」必然挤爆。
      // 全局 clamp 到 1.3：既照顾到「特大」用户（1.15/1.3 都能完整放大），
      // 又不让布局进入框架无法自适应的区间。单页仍需自己处理换行，
      // clamp 只是**兜底**，不是免死金牌。
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: _StartupFrameProbe(
          child: TodayWidgetListener(
            child: LocationTriggerListener(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// R5 任务 1：首帧打点。
///
/// 挂在 `MaterialApp.builder` 里，因此它的 `addPostFrameCallback` 就是
/// 「第一帧真正提交给合成器之后」那一刻 —— 比在 `main()` 里猜要准。
class _StartupFrameProbe extends StatefulWidget {
  const _StartupFrameProbe({required this.child});

  final Widget child;

  @override
  State<_StartupFrameProbe> createState() => _StartupFrameProbeState();
}

class _StartupFrameProbeState extends State<_StartupFrameProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupTrace.markOnce('ui.firstFrame');
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
