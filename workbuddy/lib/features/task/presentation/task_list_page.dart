import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../alarm/domain/scheduled_alarm.dart';
import '../../alarm/presentation/alarm_editor.dart';
import '../../alarm/providers/alarm_providers.dart';
import '../../diary/presentation/diary_list_page.dart';
import '../domain/task_enums.dart';
import '../domain/task_instance.dart';
import '../providers/task_providers.dart';
import 'add_task_page.dart';
import 'widgets/task_tile.dart';

/// 任务列表页：主页 · 今日任务实例。
///
/// 结构：顶部「今日进度」卡 + 任务卡列表，右下角 FAB 进入独立的
/// [AddTaskPage]（本页不再承担创建表单逻辑）。
class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key, this.clock});

  /// 可注入时钟：只有测试会用（去抖窗口要能在假时间轴上推进），
  /// 生产环境为空 → `DateTime.now()`。
  final DateTime Function()? clock;

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  /// 「刚才完成过一条」的时间戳 —— 连点去抖用（见 [_complete]）。
  DateTime? _lastCompleteAt;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  /// 去抖窗口：400ms。比一次 tap 的余波长，比人手换目标点短。
  static const Duration _completeCooldown = Duration(milliseconds: 400);

  /// 点击条目：todo → 开始计时；inProgress → 取消计时
  void _toggle(TaskInstance instance) {
    final repo = ref.read(taskRepositoryProvider);
    switch (instance.status) {
      case TaskStatus.todo:
        repo.startTimer(instance.id);
      case TaskStatus.inProgress:
        repo.cancelTimer(instance.id);
      case TaskStatus.done:
        break;
    }
  }

  /// 完成任务 + 防误触撤销（UNDO-COMPLETE §3）。
  ///
  /// 现状核实：点整行**不是**完成，整行是「开始 / 取消计时」，完成是右侧独立的
  /// ✓ 按钮（48dp 热区）。所以这里不改造点击语义，只补「5 秒内可撤销」——
  /// 误点一下能以最小代价退回去。
  ///
  /// **连点去抖（HARDENING A3）**：完成的条目会「沉底」（`watchTodayInstances`
  /// 按 done 排序），一次点击成功后列表会在手指下面重排 —— 同一个坐标的第二次
  /// 点击会落到**另一条**任务上。实测 10 连点会把 3 条任务全部标成完成。
  /// 所以这里加一个 400ms 窗口：窗口内的重复点击直接忽略（不写库、不弹提示）。
  ///
  /// messenger 在 await 之前取好：完成会触发列表流刷新，本 item 的 context
  /// 可能已经被回收，之后再 `ScaffoldMessenger.of(context)` 就不可靠了。
  Future<void> _complete(BuildContext context, TaskInstance instance) async {
    final now = _now();
    final last = _lastCompleteAt;
    if (last != null && now.difference(last) < _completeCooldown) return;
    _lastCompleteAt = now;

    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(taskRepositoryProvider);
    await repo.completeInstance(instance.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('已完成'),
          duration: const Duration(seconds: 5),
          // Flutter 3.47 起：带 action 的 SnackBar 默认 persist=true（永不自动消失）。
          // 不显式关掉，「5 秒内可撤销」就是假话，提示还会一直压住底部。
          persist: false,
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => repo.uncompleteInstance(instance.id),
          ),
        ),
      );
  }

  /// 长按已完成的任务：菜单 →「标记为未完成」→ 确认框（UNDO-COMPLETE §1/§2）。
  ///
  /// 菜单只放这一项：删除已有独立按钮、闹钟也有独立按钮，重复列出只会增加误触面。
  Future<void> _openDoneMenu(BuildContext context, TaskInstance instance) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                instance.titleSnapshot,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
              subtitle: const Text('已完成'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('标记为未完成'),
              onTap: () => Navigator.pop(sheetContext, 'uncomplete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'uncomplete' && context.mounted) {
      await _confirmUncomplete(context, instance);
    }
  }

  /// 取消完成前的确认框：反向操作必须明确确认，不用 SnackBar 撤销。
  Future<void> _confirmUncomplete(
    BuildContext context,
    TaskInstance instance,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('标记为未完成'),
        content: Text('要把「${instance.titleSnapshot}」标记回未完成吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('标记为未完成'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(taskRepositoryProvider).uncompleteInstance(instance.id);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskInstance instance,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        // 说真话：删的是「任务本身」，不是今天这一条。重复任务明天不会再来
        content: Text(
          '确定删除「${instance.titleSnapshot}」吗？此任务的重复计划也会一并移除，之后不会再出现。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // 走编排：撤闹钟 → 归档模板 → 软删实例（见 DeleteTask）
      await ref.read(deleteTaskProvider)(instance);
    }
  }

  /// 新建任务：跳转独立页面。
  ///
  /// 表单、写入与「已创建」提示都在 [AddTaskPage] 内（成功时 pop(true)），
  /// 本页只负责导航；新任务由 `todayInstancesProvider` 的流自动入列。
  Future<void> _openAddTask(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddTaskPage()));
  }

  /// 打开闹钟设置（T10 的最小调度入口）
  Future<void> _openAlarmEditor(
    BuildContext context,
    TaskInstance instance,
    ScheduledAlarm? existing,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlarmEditorDialog(
        taskId: instance.templateId,
        taskTitle: instance.titleSnapshot,
        defaultRepeatRule: 'daily',
        existing: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncInstances = ref.watch(todayInstancesProvider);
    final alarmsByTask = ref.watch(alarmsByTaskProvider);

    return Scaffold(
      // T22：日记入口放在 AppBar（**不动底部 3 标签**，保持既有导航指纹）
      appBar: AppBar(
        title: const Text('今日任务'),
        actions: [
          IconButton(
            tooltip: '日记',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const DiaryListPage()),
            ),
          ),
        ],
      ),
      body: asyncInstances.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          message: _readableError(error),
          onRetry: () => ref.invalidate(todayInstancesProvider),
        ),
        data: (instances) {
          if (instances.isEmpty) {
            return const EmptyState(
              icon: Icons.task_alt,
              title: '今日暂无任务',
              subtitle: '点击右下角 + 创建你的第一个任务',
            );
          }

          final doneCount = instances
              .where((instance) => instance.status == TaskStatus.done)
              .length;

          return Column(
            // 让顶部进度卡横向拉满，与水波纹列表卡同宽（D7 对齐）
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TodayProgressHeader(total: instances.length, done: doneCount),
              Expanded(
                child: ListView.separated(
                  // 底部留出悬浮按钮的高度，最后一张卡不会被挡住
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.pagePadding,
                    AppDimens.cardGap / 2,
                    AppDimens.pagePadding,
                    AppDimens.minTapSize * 2,
                  ),
                  itemCount: instances.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimens.cardGap),
                  itemBuilder: (context, index) {
                    final instance = instances[index];
                    final alarm = alarmsByTask[instance.templateId];
                    return TaskTile(
                      instance: instance,
                      alarm: alarm,
                      onToggle: () => _toggle(instance),
                      onComplete: () => _complete(context, instance),
                      onDelete: () => _confirmDelete(context, instance),
                      onAlarm: () =>
                          _openAlarmEditor(context, instance, alarm),
                      // 只有已完成的任务才有「标记为未完成」可做
                      onLongPress: instance.status == TaskStatus.done
                          ? () => _openDoneMenu(context, instance)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // 高频操作下沉至屏幕下半区
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTask(context),
        tooltip: '新建任务',
        icon: const Icon(Icons.add),
        label: const Text('新建任务'),
      ),
    );
  }
}

/// 顶部进度区：今天几号 + 已完成 x / y + 绿色进度条（100% 给一句鼓励）。
class _TodayProgressHeader extends StatelessWidget {
  const _TodayProgressHeader({required this.total, required this.done});

  final int total;
  final int done;

  static const double _iconSize = 18;
  static const double _progressHeight = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double ratio = total == 0 ? 0.0 : done / total;
    final allDone = total > 0 && done >= total;

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.today_outlined,
                size: _iconSize,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppDimens.sectionHeaderGap),
              // 日期占剩余宽度，窄屏时省略而不是把「已完成 x / y」挤掉
              Expanded(
                child: Text(
                  _dateLabel(DateTime.now()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '已完成 $done / $total',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: allDone
                      ? AppColors.success
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.sectionHeaderGap),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: _progressHeight,
              color: AppColors.success,
              // 轨道用中性色：之前用 success@16%，导致 0/1 时整条浅绿、看起来像"已满"
              // （D4 状态色要能区分状态，不能把"没开始"也涂成绿的）。
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          if (allDone) ...[
            const SizedBox(height: AppDimens.sectionHeaderGap),
            Text(
              '今天的任务全部完成，保持这个节奏',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _dateLabel(DateTime now) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.month}月${now.day}日 · ${weekdays[now.weekday - 1]}';
  }
}

/// 加载态：转圈 + 一句说明（避免只转圈不知道在等什么）。
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppDimens.cardGap),
          Text(
            '正在加载今日任务…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 错误态：可读信息 + 重试按钮（R3：错误必须有重试入口）。
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(icon: Icons.cloud_off, title: '加载失败', subtitle: message),
            const SizedBox(height: AppDimens.cardGap),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 把异常转成一句人话：去掉 `Exception:` 前缀，过长则截断。
String _readableError(Object error) {
  const maxChars = 120;
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  if (raw.isEmpty) return '请检查后重试';
  return raw.length > maxChars ? '${raw.substring(0, maxChars)}…' : raw;
}
