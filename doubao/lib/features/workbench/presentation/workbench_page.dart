import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

/// 自定义工作台占位页（P1，后续迭代实现任务/表格/笔记三种模式）
class WorkbenchPage extends StatelessWidget {
  const WorkbenchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工作台')),
      body: const EmptyState(
        icon: Icons.space_dashboard_outlined,
        message: '自定义工作台开发中\n将支持任务、表格、笔记三种分区模式',
      ),
    );
  }
}
