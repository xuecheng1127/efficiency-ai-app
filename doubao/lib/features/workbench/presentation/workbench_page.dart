import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../diary/providers/diary_providers.dart';
import '../../task/providers/task_providers.dart';
import '../providers/workbench_provider.dart';

/// 自定义工作台（P1）
///
/// 三种模式：只看任务 / 只看日记 / 两者都看
/// 未配置时展示空态 + 3 个预设按钮一键起步
class WorkbenchPage extends ConsumerWidget {
  const WorkbenchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workbenchModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('工作台'),
        actions: [
          if (mode != WorkbenchMode.unconfigured)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: '配置工作台',
              onPressed: () => _showConfigSheet(context, ref, mode),
            ),
        ],
      ),
      body: mode == WorkbenchMode.unconfigured
          ? const _UnconfiguredView()
          : ListView(
              padding: const EdgeInsets.all(AppColors.pagePadding),
              children: [
                if (mode == WorkbenchMode.tasksOnly || mode == WorkbenchMode.both)
                  const _TaskCard(),
                if (mode == WorkbenchMode.tasksOnly || mode == WorkbenchMode.both)
                  const SizedBox(height: 16),
                if (mode == WorkbenchMode.diaryOnly || mode == WorkbenchMode.both)
                  const _DiaryCard(),
              ],
            ),
    );
  }

  void _showConfigSheet(
      BuildContext context, WidgetRef ref, WorkbenchMode current) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('工作台显示内容',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            RadioListTile<WorkbenchMode>(
              value: WorkbenchMode.tasksOnly,
              groupValue: current,
              title: const Text('只看任务'),
              onChanged: (v) {
                ref.read(workbenchModeProvider.notifier).set(v!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<WorkbenchMode>(
              value: WorkbenchMode.diaryOnly,
              groupValue: current,
              title: const Text('只看日记'),
              onChanged: (v) {
                ref.read(workbenchModeProvider.notifier).set(v!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<WorkbenchMode>(
              value: WorkbenchMode.both,
              groupValue: current,
              title: const Text('任务 + 日记'),
              onChanged: (v) {
                ref.read(workbenchModeProvider.notifier).set(v!);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 未配置空态：3 个预设按钮一键起步
class _UnconfiguredView extends ConsumerWidget {
  const _UnconfiguredView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.space_dashboard_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('工作台还没配置',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('选择一个起步，之后可随时调整',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('只看任务'),
                onPressed: () => ref
                    .read(workbenchModeProvider.notifier)
                    .set(WorkbenchMode.tasksOnly),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.book_outlined),
                label: const Text('只看日记'),
                onPressed: () => ref
                    .read(workbenchModeProvider.notifier)
                    .set(WorkbenchMode.diaryOnly),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('任务 + 日记'),
                onPressed: () => ref
                    .read(workbenchModeProvider.notifier)
                    .set(WorkbenchMode.both),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 任务卡：真实今日进度
class _TaskCard extends ConsumerWidget {
  const _TaskCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(taskStatsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text('今日任务',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${stats.done} / ${stats.total}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stats.progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              stats.total == 0
                  ? '今天还没有任务'
                  : '已完成 ${stats.done} 件，'
                      '进行中 ${stats.inProgress} 件，'
                      '累计 ${stats.formattedDuration}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// 日记卡：最新一篇
class _DiaryCard extends ConsumerWidget {
  const _DiaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaries = ref.watch(diariesProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: diaries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('错误: $e'),
          data: (list) {
            if (list.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.book_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('最近日记',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 12),
                  Text('还没有日记，去日记页写一篇吧',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              );
            }
            final latest = list.first;
            final title = latest.title.isEmpty ? '（无标题）' : latest.title;
            final rawTs = latest.diaryDate == 0
                ? latest.createdAt
                : latest.diaryDate;
            // 防御：时间戳超出合理范围时显示「日期异常」
            final date = DateTime.fromMillisecondsSinceEpoch(rawTs);
            final dateStr = (date.year < 1900 || date.year > 2100)
                ? '日期异常'
                : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.book_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('最近日记',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(dateStr,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
                const SizedBox(height: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  latest.content.length > 80
                      ? '${latest.content.substring(0, 80)}…'
                      : latest.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
