import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/services/alarm_service.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/providers/settings_provider.dart';
import '../features/splash/splash_page.dart';
import '../shell/main_shell.dart';

/// 应用根组件
///
/// 职责：
/// - 监听全局设置（主题模式）并构建对应主题；
/// - 冷启动：先显示启动页（Logo 保底 2 秒 + 数据加载），
///   完成后切换到主框架；
/// - 热启动/后台切回：由系统重建 Activity，路由始终从主框架进入，
///   不重复展示启动页（SplashPage 仅作为冷启动首屏）。

/// 全局 navigatorKey：用于页面 pop 后仍能弹窗（权限引导等副作用）
final navigatorKey = GlobalKey<NavigatorState>();

class EfficiencyApp extends ConsumerStatefulWidget {
  const EfficiencyApp({super.key});

  @override
  ConsumerState<EfficiencyApp> createState() => _EfficiencyAppState();
}

class _EfficiencyAppState extends ConsumerState<EfficiencyApp>
    with WidgetsBindingObserver {
  bool _showSplash = true;

  /// T12：上次已知的精确闹钟权限档位（用于检测系统设置变更）
  bool? _lastExactAlarmTier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // T12：启动时无条件重排全部闹钟（BOOT_COMPLETED 被 ROM 拦掉时的自愈机会）
    _rescheduleAllOnStartup();
    // 启动时记录初始档位
    _refreshExactAlarmTier();
  }

  Future<void> _rescheduleAllOnStartup() async {
    try {
      await AlarmService.instance.rescheduleAll();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// T12 前台兜底：检查精确闹钟权限档位，变化则重排全部闹钟
  Future<void> _refreshExactAlarmTier() async {
    try {
      final current = await AlarmService.instance.canScheduleExactAlarms();
      if (_lastExactAlarmTier != null && _lastExactAlarmTier != current) {
        await AlarmService.instance.rescheduleAll();
      }
      _lastExactAlarmTier = current;
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshExactAlarmTier();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 全局设置：主题模式（浅色/深色/跟随系统）
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.valueOrNull?.themeMode ?? ThemeMode.system;

    return MaterialApp(
      title: '效率助手',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // 冷启动流程：Splash → MainShell（带 260ms 淡入过渡）
      home: _showSplash
          ? SplashPage(
              onDone: () {
                if (mounted) {
                  setState(() => _showSplash = false);
                }
              },
            )
          : const MainShell()
              .animate()
              .fadeIn(duration: 260.ms, curve: AppMotion.easeOutCubic),
    );
  }
}
