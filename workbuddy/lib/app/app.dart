import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/location/presentation/location_trigger_listener.dart';
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
      builder: (context, child) =>
          LocationTriggerListener(child: child ?? const SizedBox.shrink()),
    );
  }
}
