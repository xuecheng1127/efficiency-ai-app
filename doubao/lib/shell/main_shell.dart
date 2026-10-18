import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../features/diary/presentation/diary_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/task/presentation/task_list_page.dart';
import '../features/toolbox/presentation/toolbox_page.dart';
import '../features/workbench/presentation/workbench_page.dart';

/// 应用主框架（底部导航）
///
/// 五个一级模块：主页（任务）/ 日记 / 工具箱 / 工作台 / 设置。
/// - 主页默认展示任务体系（P0）；
/// - 工具箱默认收纳扩展功能（P1 插件体系，默认不显示在主页）；
/// - 热启动/从后台切回时不显示启动页（启动页只在冷启动路由中使用）。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = <Widget>[
    TaskListPage(),
    DiaryPage(),
    ToolboxPage(),
    WorkbenchPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
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
