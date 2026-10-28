import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../diary/domain/diary_entry.dart';
import '../../diary/presentation/diary_list_page.dart';
import '../../diary/providers/diary_providers.dart';
import '../../streak/presentation/streak_button.dart';
import '../../task/domain/task_enums.dart';
import '../../task/domain/task_instance.dart';
import '../../task/presentation/task_list_page.dart';
import '../../task/providers/task_providers.dart';
import '../domain/workbench_module.dart';
import '../providers/workbench_providers.dart';
import 'workbench_config_page.dart';
import 'workbench_icons.dart';

/// ============================================================================
/// 工作台（模块4 · P1）
/// ============================================================================
///
/// 一句话：**主页显示什么，由用户决定**。
///
/// 与 PRD 的差距（如实标注）：P1 只做「选哪几个模块」，不做无限分区、
/// 不做拖拉拽布局、不做表格模式。模块内容**全部复用**已有 feature 的数据层，
/// 工作台本身不写任何业务逻辑 —— 否则同一份数据两套代码，迟早对不上。
class WorkbenchPage extends ConsumerWidget {
  const WorkbenchPage({super.key});

  Future<void> _openConfig(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const WorkbenchConfigPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(workbenchModulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('工作台'),
        actions: [
          // 火花入口（首页 AppBar 右侧）：🔥 + 连续天数 → 勋章页
          const StreakButton(),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '配置工作台',
            onPressed: () => _openConfig(context),
          ),
        ],
      ),
      body: modules.isEmpty
          ? const _WorkbenchEmpty()
          : _WorkbenchBody(modules: modules),
    );
  }
}

/// 已配置：按顺序渲染模块卡片。
class _WorkbenchBody extends StatelessWidget {
  const _WorkbenchBody({required this.modules});

  final List<WorkbenchModule> modules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
      children: [
        const AppSectionHeader('我的工作台'),
        for (final module in modules)
          switch (module) {
            WorkbenchModule.tasks => const _TasksModuleCard(),
            WorkbenchModule.diary => const _DiaryModuleCard(),
          },
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.sectionGap,
            AppDimens.pagePadding,
            0,
          ),
          child: Text(
            '想换个组合？点右上角「配置」，或下拉刷新看最新数据。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// 空态：还没配置 → 给 3 个预设一键起步（要求 4）。
class _WorkbenchEmpty extends ConsumerWidget {
  const _WorkbenchEmpty();

  static const Map<String, IconData> _presetIcons = {
    'tasks_only': Icons.checklist_rounded,
    'diary_only': Icons.auto_stories_outlined,
    'both': Icons.space_dashboard_outlined,
  };

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    WorkbenchPreset preset,
  ) async {
    await ref.read(workbenchConfigProvider).applyPreset(preset);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已应用预设：${preset.label}')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.sectionGap * 2,
            AppDimens.pagePadding,
            AppDimens.sectionGap,
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(
                    AppDimens.cardRadius * 1.5,
                  ),
                ),
                child: Icon(
                  Icons.dashboard_customize_outlined,
                  size: 30,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppDimens.sectionGap),
              Text('工作台还没配置', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppDimens.sectionHeaderGap),
              Text(
                '选一个预设直接开始，或者自己挑模块。\n配置随时可以在右上角修改。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const AppSectionHeader('预设模式', subtitle: '点一下即生效，之后还能改'),
        for (final preset in kWorkbenchPresets)
          AppCard(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimens.cardPadding,
            ),
            child: AppActionTile(
              icon: _presetIcons[preset.id] ?? Icons.dashboard_outlined,
              title: preset.label,
              subtitle: preset.description,
              onTap: () => _apply(context, ref, preset),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.sectionGap,
            AppDimens.pagePadding,
            0,
          ),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.tune),
            label: const Text('手动选择模块'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const WorkbenchConfigPage()),
            ),
          ),
        ),
      ],
    );
  }
}

/// 模块卡片通用头：图标 + 标题 + 状态摘要 + 右侧动作（D1/D2/D3）。
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.cardGap,
        AppDimens.chipGap,
        AppDimens.cardGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppModuleIcon(icon),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
          Divider(
            height: AppDimens.sectionGap,
            color: theme.colorScheme.outlineVariant,
          ),
          child,
        ],
      ),
    );
  }
}

/// 任务模块：真实读 `todayInstancesProvider`（复用任务模块的数据层）。
class _TasksModuleCard extends ConsumerWidget {
  const _TasksModuleCard();

  static const int _previewLimit = 3;

  void _openTasks(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TaskListPage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncItems = ref.watch(todayInstancesProvider);

    final items = asyncItems.value ?? const <TaskInstance>[];
    final total = items.length;
    final done = items.where((i) => i.status == TaskStatus.done).length;

    // 刻意不用 `AsyncValue.when`：有旧数据时再刷新不该闪成骨架屏。
    final Widget content;
    if (asyncItems.hasError && !asyncItems.hasValue) {
      content = _InlineError(
        message: '任务数据读取失败',
        onRetry: () => ref.invalidate(todayInstancesProvider),
      );
    } else if (!asyncItems.hasValue) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.cardGap),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (total == 0) {
      content = Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.cardGap),
        child: Text(
          '建一个任务，今天的进度就会出现在这里。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.chipGap),
            child: LinearProgressIndicator(
              value: done / total,
              minHeight: 6,
              color: AppColors.success,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppDimens.cardGap),
          for (final item in items.take(_previewLimit))
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.chipGap),
              child: _TaskPreviewRow(item: item),
            ),
          if (total > _previewLimit)
            Text(
              '还有 ${total - _previewLimit} 条未显示',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    }

    return _ModuleCard(
      icon: workbenchModuleIcon(WorkbenchModule.tasks),
      title: WorkbenchModule.tasks.label,
      subtitle: asyncItems.hasError
          ? '读取失败，下拉刷新重试'
          : total == 0
          ? '今天还没有任务'
          : '已完成 $done / $total',
      actionLabel: total == 0 ? '去创建' : '查看全部',
      onAction: () => _openTasks(context),
      child: content,
    );
  }
}

/// 任务预览行：**不可点击**（避免"看着能点、点了只跳页"的假控件）。
/// 想操作就去任务列表，那里才是真入口。
class _TaskPreviewRow extends StatelessWidget {
  const _TaskPreviewRow({required this.item});

  final TaskInstance item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = item.status == TaskStatus.done;
    final color = switch (item.status) {
      TaskStatus.todo => AppColors.todo,
      TaskStatus.inProgress => AppColors.active,
      TaskStatus.done => AppColors.success,
    };

    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: AppDimens.chipGap),
        // 标题吃掉剩余宽度（超长时省略），与右侧状态之间留一格间距：
        // 没有这一格，长标题的「…」会紧贴「未开始」，看起来像两个词粘在一起。
        Expanded(
          child: Text(
            item.titleSnapshot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDone ? theme.colorScheme.onSurfaceVariant : null,
              decoration: isDone ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.chipGap),
        Text(switch (item.status) {
          TaskStatus.todo => '未开始',
          TaskStatus.inProgress => '计时中',
          TaskStatus.done => '已完成',
        }, style: theme.textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}

/// 日记模块：真实读 `diaryRowsProvider`（复用日记模块的数据层）。
class _DiaryModuleCard extends ConsumerWidget {
  const _DiaryModuleCard();

  void _openDiary(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DiaryListPage()));
  }

  static String _dateLabel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '今天';
    }
    return '${d.month}月${d.day}日';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncRows = ref.watch(diaryRowsProvider);
    final rows = asyncRows.value ?? const <DiaryListRow>[];
    final latest = rows.isEmpty ? null : rows.first;

    final Widget content;
    if (asyncRows.hasError && !asyncRows.hasValue) {
      content = _InlineError(
        message: '日记读取失败',
        onRetry: () => ref.invalidate(diaryRowsProvider),
      );
    } else if (!asyncRows.hasValue) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.cardGap),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (latest == null) {
      content = Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.cardGap),
        child: Text(
          '日记写在这里，工作台会显示最近一篇的开头。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            latest.entry.title.trim().isEmpty ? '（无标题）' : latest.entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppDimens.chipGap),
          Text(
            latest.entry.summary(maxChars: 60),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.cardGap),
        ],
      );
    }

    return _ModuleCard(
      icon: workbenchModuleIcon(WorkbenchModule.diary),
      title: WorkbenchModule.diary.label,
      subtitle: asyncRows.hasError
          ? '读取失败，下拉刷新重试'
          : latest == null
          ? '还没有日记'
          : '最近：${_dateLabel(latest.entry.diaryDate)}',
      actionLabel: latest == null ? '写一篇' : '打开',
      onAction: () => _openDiary(context),
      child: content,
    );
  }
}

/// 卡片内的轻量错误行（带重试入口，D5）。
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.cardGap),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: AppDimens.chipGap),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
