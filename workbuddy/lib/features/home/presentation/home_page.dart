import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/providers/backup_providers.dart';
import '../../settings/presentation/settings_page.dart';
import '../../task/presentation/task_list_page.dart';
import '../../toolbox/presentation/toolbox_page.dart';
import '../../workbench/presentation/workbench_page.dart';
import '../providers/home_tab.dart';

/// 主页：底部导航（工作台 / 任务 / 工具箱 / 设置）。
///
/// 为什么工作台单独占一格、而不是直接替换掉「任务」：
/// 工作台是**可配置的组合视图**（模块可选），任务页是**完整功能页**。
/// 把任务塞进工作台会二选一地牺牲功能（FAB、筛选、删除…），
/// 而保留独立任务页则用户在关掉任务模块后依然能管理任务。
///
/// 当前 tab 存在 [homeTabProvider]（不是 `setState`）：全局搜索页搜到任务后
/// 要「回到任务页」，那一步得从搜索页改主页 tab，跨页面共享状态只能这么给。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const List<Widget> _pages = [
    WorkbenchPage(),
    TaskListPage(),
    ToolboxPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 自动备份（R3 任务 2）：首帧之后再做。
    // 不在 initState 里直接 await 的两个理由：
    // 1. 备份要 checkpoint + 解压打包，会和首帧抢 IO，冷启动会白屏一下；
    // 2. 成功提示要 `ScaffoldMessenger`，它在首帧之后才挂上。
    //
    // R5：首帧之后再等 3 秒。原因是有数据时备份要打 ZIP（实测 500KB 库约 120ms
    // IO），如果紧贴首帧执行，正好撞上用户第一次点击/滚动，会被当成"卡了一下"。
    // 3 秒是「首屏已经稳定」和「用户还没走远」之间的折中；启动关键路径上
    // 不再有任何备份相关的 IO。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 3), _maybeAutoBackup);
    });
  }

  Future<void> _maybeAutoBackup() async {
    if (!mounted) return;
    // 失败静默：自动备份是「用户没要求、我们替他做」的事，
    // 失败时弹红条只会让他在开屏就挨一个他自己没触发的错误。
    // 真正的状态在设置页那一行（「上次备份：X 天前」）。
    final result = await ref.read(autoBackupServiceProvider).maybeBackup();
    if (!mounted || !result.created) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已自动备份（第 ${result.keptCount} 份）'),
          duration: const Duration(seconds: 2),
          // 无 action 的 SnackBar 默认就会消失，这里显式写出来是防回归：
          // 一旦以后有人加了 action，persist 默认为 true，提示会永久压住底部导航。
          persist: false,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(homeTabProvider);

    return Scaffold(
      // IndexedStack 保持各 tab 状态不丢失
      body: IndexedStack(index: index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(homeTabProvider.notifier).select,
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
