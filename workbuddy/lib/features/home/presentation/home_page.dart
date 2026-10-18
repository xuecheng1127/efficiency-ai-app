import 'package:flutter/material.dart';

import '../../settings/presentation/settings_page.dart';
import '../../task/presentation/task_list_page.dart';
import '../../toolbox/presentation/toolbox_page.dart';
import '../../workbench/presentation/workbench_page.dart';

/// 主页：底部导航（工作台 / 任务 / 工具箱 / 设置）。
///
/// 为什么工作台单独占一格、而不是直接替换掉「任务」：
/// 工作台是**可配置的组合视图**（模块可选），任务页是**完整功能页**。
/// 把任务塞进工作台会二选一地牺牲功能（FAB、筛选、删除…），
/// 而保留独立任务页则用户在关掉任务模块后依然能管理任务。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const List<Widget> _pages = [
    WorkbenchPage(),
    TaskListPage(),
    ToolboxPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack 保持各 tab 状态不丢失
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '工作台',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: '任务',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension),
            label: '工具箱',
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
