import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/alarm_service.dart';
import '../../../core/services/task_timer_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/task_repository.dart';
import '../providers/task_providers.dart';
import '../providers/task_timer_provider.dart';
import 'add_task_page.dart';
import 'widgets/task_card.dart';
import '../../streak/providers/streak_provider.dart';
import '../../streak/presentation/medals_page.dart';

/// 主页 · 任务体系（P0 核心）
///
/// 职责：
/// - 展示今日任务列表（自动补齐重复任务的当日实例）；
/// - 三态流转：点击图标完成 / 点击卡片开始计时 / 完成态点击撤销；
/// - 计时器（V1.1）：开始计时自动启动前台服务（后台不中断），
///   页面顶部展示实时计时横幅（应用内优先级第二：通知栏 → 横幅）；
/// - 长按任务弹出操作菜单（归档/删除）；
/// - 空状态页：无任务时展示引导；
/// - 添加按钮沉底（单手优化）。
///
/// 性能说明：仅订阅 timer.occurrenceId / title（开始/结束才变化），
/// 每秒心跳由横幅与卡片内部的独立 Consumer 刷新，避免整页重建。
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayTasks = ref.watch(todayTasksProvider);
    final stats = ref.watch(taskStatsProvider);
    // 只订阅开始/结束变化，不随每秒心跳重建
    final timerOccId = ref.watch(
      taskTimerProvider.select((s) => s.occurrenceId),
    );
    final timerTitle = ref.watch(
      taskTimerProvider.select((s) => s.title),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('今天'),
        // 顶部进度信息
        actions: [
          // 火花：点进勋章页
          Consumer(
            builder: (context, ref, _) {
              final s = ref.watch(streakProvider);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MedalsPage()),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          s.maybeWhen(
                            data: (d) => '${d.current}',
                            orElse: () => '0',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (stats.total > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${stats.done}/${stats.total} · ${stats.formattedDuration}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 应用内顶部横幅：进行中任务实时计时（优先级：通知栏 → 横幅）
          if (timerOccId != -1)
            _ActiveTimerBanner(occurrenceId: timerOccId, title: timerTitle),
          Expanded(
            child: todayTasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    const Text('加载失败，请重试', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(todayTasksProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return EmptyState(
                    icon: Icons.checklist_rtl,
                    message: '今天还没有任务\n点击下方按钮，创建你的第一个任务',
                    actionLabel: '新建任务',
                    onAction: () => _openAddPage(context),
                  );
                }
                // 列表自适应：任务少时压缩留白，多时纵向滚动（需求 1.7）
                return ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppColors.pagePadding,
                    4,
                    AppColors.pagePadding,
                    100,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final item = tasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TaskCard(
                        item: item,
                        // 仅当前计时任务标记为活跃，卡片内部单独刷新秒数
                        isActiveTimer: item.occurrence.id == timerOccId,
                        onStart: () => _startTask(context, ref, item),
                        onComplete: () => _completeTask(ref, item),
                        onReopen: () => _reopenTask(ref, item),
                        onLongPress: () => _showTaskMenu(context, ref, item),
                      )
                          .animate()
                          .fadeIn(
                            duration: 260.ms,
                            curve: AppMotion.easeOutCubic,
                            delay: (index * 40).ms,
                          ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // 添加按钮沉底（需求：高频操作按钮统一下沉至下半区）
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddPage(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新建任务'),
      ),
    );
  }

  // ==================== 三态流转 ====================

  /// 点击开始计时 → 进行中（场景化申请通知权限后启动前台服务）
  Future<void> _startTask(
    BuildContext context,
    WidgetRef ref,
    TaskWithOccurrence item,
  ) async {
    // 场景化权限申请：首次使用计时功能时，说明用途 + 用户收益
    final granted = await _ensureNotificationPermission(context);
    if (!granted && context.mounted) {
      // 降级兜底：权限被拒时仍允许应用内计时（无通知栏常驻）
      _showPermissionFallback(context);
    }
    // 计时控制器：写库（inProgress + startedAt）→ 启动前台服务 → 心跳
    final timerNotifier = ref.read(taskTimerProvider.notifier);
    await timerNotifier.start(
      occurrenceId: item.occurrence.id!,
      title: item.occurrence.titleSnapshot,
    );
  }

  /// 点击完成 → 已完成（自动归档耗时，计时器同步停止并回填）
  Future<void> _completeTask(
    WidgetRef ref,
    TaskWithOccurrence item,
  ) async {
    final timer = ref.read(taskTimerProvider);
    if (timer.occurrenceId == item.occurrence.id && timer.active) {
      // 正在计时的任务：走计时器完成（回填耗时 + 停止前台服务）
      await ref.read(taskTimerProvider.notifier).complete();
    } else {
      // 非计时中：直接完成
      final repo = ref.read(taskRepositoryProvider);
      await repo.completeTask(item.occurrence.id!);
    }
  }

  /// 撤销完成
  Future<void> _reopenTask(
    WidgetRef ref,
    TaskWithOccurrence item,
  ) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.reopenTask(item.occurrence.id!);
  }

  /// 长按菜单：归档 / 删除
  Future<void> _showTaskMenu(
    BuildContext context,
    WidgetRef ref,
    TaskWithOccurrence item,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑任务'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('归档任务（保留历史记录）'),
              onTap: () => Navigator.pop(ctx, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('删除任务', style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (!context.mounted) return;

    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddTaskPage(taskId: item.task.id)),
      );
      return;
    }
    final repo = ref.read(taskRepositoryProvider);
    if (action == 'archive') {
      await repo.archiveTask(item.task.id!);
      // 归档任务不再提醒（V1.2 闹钟联动）
      await AlarmService.instance.cancelTaskAlarm(item.task.id!);
    } else if (action == 'delete') {
      // 删除任务模板与其全部当日实例
      await repo.deleteTask(item.task.id!);
      // 删除后取消闹钟（V1.2 闹钟联动）
      await AlarmService.instance.cancelTaskAlarm(item.task.id!);
    }
  }

  /// 场景化通知权限申请（Android 13+ 必需，首次计时时触发）
  Future<bool> _ensureNotificationPermission(BuildContext context) async {
    if (await TaskTimerService.instance.hasNotificationPermission()) return true;

    // 弹窗说明「权限用途 + 用户收益」，提供「去开启」「暂不」双选项
    final goOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('开启计时通知'),
        content: const Text(
          '需要通知权限才能在通知栏常驻显示任务计时（含暂停/完成按钮），'
          '退出应用后计时也不会中断。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去开启'),
          ),
        ],
      ),
    );

    if (goOpen != true) return false;
    return TaskTimerService.instance.requestNotificationPermission();
  }

  /// 权限被拒降级提示（仅提示一次，不反复弹窗骚扰）
  void _showPermissionFallback(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('未开启通知，计时将只在应用内显示（可在设置中随时开启）'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openAddPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddTaskPage()),
    );
  }
}

/// 应用内顶部横幅：进行中任务实时计时
///
/// 展示优先级（需求 1.3）：通知栏常驻计时 → 应用内顶部横幅 → 悬浮窗。
/// V1.1 实现前两级；横幅含「暂停 / 完成」快捷操作。
///
/// 性能说明：本组件整体不随每秒心跳重建——外层骨架只依赖
/// occurrenceId/title（开始/结束才变化），实时秒数由内部 Consumer 单独刷新。
class _ActiveTimerBanner extends ConsumerWidget {
  final int occurrenceId;
  final String title;

  const _ActiveTimerBanner({
    required this.occurrenceId,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              // 呼吸圆点动画（进行中标识）
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 600.ms, curve: Curves.easeInOut)
                  .then()
                  .fadeOut(duration: 600.ms, curve: Curves.easeInOut),
              const SizedBox(width: 12),
              // 任务名 + 实时计时（秒数由内部 Consumer 单独刷新）
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Consumer(
                      builder: (context, ref, _) {
                        final elapsed = ref.watch(
                          taskTimerProvider.select((s) => s.elapsedSeconds),
                        );
                        return Text(
                          _formatElapsed(elapsed),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // 暂停 / 完成（可点击区域 ≥44dp）
              TextButton.icon(
                onPressed: () => ref.read(taskTimerProvider.notifier).pause(),
                icon: const Icon(Icons.pause_circle_outline, size: 20),
                label: const Text('暂停'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () => ref.read(taskTimerProvider.notifier).complete(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatElapsed(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
