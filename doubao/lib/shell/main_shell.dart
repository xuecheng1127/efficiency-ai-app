import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auto_backup_service.dart';
import '../core/services/home_widget_service.dart';
import '../features/diary/presentation/diary_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/task/presentation/task_list_page.dart';
import '../features/task/providers/task_providers.dart';
import '../features/toolbox/presentation/toolbox_page.dart';
import '../features/workbench/presentation/workbench_page.dart';

/// 应用主框架（底部导航）
///
/// 五个一级模块：主页（任务）/ 日记 / 工具箱 / 工作台 / 设置。
/// - 主页默认展示任务体系（P0）；
/// - 工具箱默认收纳扩展功能（P1 插件体系，默认不显示在主页）；
/// - 热启动/从后台切回时不显示启动页（启动页只在冷启动路由中使用）。
/// - R3：监听今日任务变化，同步桌面小组件。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _pages = <Widget>[
    TaskListPage(),
    DiaryPage(),
    ToolboxPage(),
    WorkbenchPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 启动时检查一次自动备份；在前台且成功时弹不打扰的轻提示
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoBackup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从后台切回前台时，用最新任务列表刷新一次小组件
    if (state == AppLifecycleState.resumed) {
      final list = ref.read(todayTasksProvider).valueOrNull;
      if (list != null) HomeWidgetService.syncTodayTasks(list);
    }
  }

  Future<void> _maybeAutoBackup() async {
    final result = await AutoBackupService.instance.maybeBackup();
    if (!mounted || !result.created) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已自动备份（第 ${result.keptCount} 份）'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod 要求 ref.listen 在 build 内注册；任务列表变化（新建/完成/删除）时同步桌面小组件
    ref.listen(todayTasksProvider, (_, next) {
      final list = next.valueOrNull;
      if (list != null) HomeWidgetService.syncTodayTasks(list);
    });
    return Scaffold(
      // IndexedStack 保留各页状态，切换无重建（热启动不重复加载）
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        // Material 3 NavigationBar，指标动画 260ms easeOutCubic
        animationDuration: AppMotion.pageTransition,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '主页',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '日记',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets),
            label: '工具箱',
          ),
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: '工作台',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
