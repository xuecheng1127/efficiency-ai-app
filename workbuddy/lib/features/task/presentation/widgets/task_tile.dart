import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../alarm/domain/scheduled_alarm.dart';
import '../../domain/task_enums.dart';
import '../../domain/task_instance.dart';
import '../../providers/task_ticker_provider.dart';

/// 任务条目：一张卡承载「状态指示 + 标题 + 元信息 + 动作区」。
///
/// 交互契约（本次只改视觉，行为保持原样）：
/// - 点击卡体：todo → 开始计时；inProgress → 取消计时；done → 无动作
///   （done 时 `onTap` 为 null，既不响应也没有水波纹，不会「看着能点」）
/// - 长按卡体：仅已完成时可用，弹出「标记为未完成」菜单（UNDO-COMPLETE）
/// - 完成按钮：未完成 / 进行中可用；**已完成时 `onPressed: null` 并灰化**
/// - 闹钟按钮：始终可点（已完成的任务仍允许编辑闹钟）
/// - 删除按钮：沿用原有入口，点击后由调用方弹确认框
///
/// 计时（P0-3）：`inProgress` 时订阅 [taskTickerProvider]，每秒重建本卡，
/// 元信息里的 `已计时 HH:MM:SS` 会真的走秒。
class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.instance,
    required this.onToggle,
    required this.onComplete,
    required this.onDelete,
    required this.onAlarm,
    this.alarm,
    this.onLongPress,
  });

  final TaskInstance instance;

  /// 开始 / 取消计时
  final VoidCallback onToggle;

  /// 完成任务
  final VoidCallback onComplete;

  /// 删除任务
  final VoidCallback onDelete;

  /// 设置 / 编辑闹钟（T10 的最小调度入口）
  final VoidCallback onAlarm;

  /// 长按（已完成时由调用方接上「标记为未完成」菜单；其余状态传 null）
  final VoidCallback? onLongPress;

  /// 该任务已持久化的闹钟（null = 未设置）
  final ScheduledAlarm? alarm;

  /// 状态圆点直径（三态共用同一占位尺寸，保证标题左边缘对齐）
  static const double _indicatorSize = 24;

  /// 空心圆 / 蓝色环的描边宽度
  static const double _ringWidth = 2;

  /// 进行中的「计时点」直径（环内小圆点 = 正在跑）
  static const double _runningDotSize = 8;

  /// 右侧动作按钮的点击热区（与 AppDimens.minTapSize 对齐）
  static const double _actionSize = AppDimens.minTapSize;

  /// 动作图标尺寸（比默认 24 略小，三个按钮并排时才放得下）
  static const double _actionIconSize = 20;

  /// 标题与元信息之间的行距
  static const double _titleMetaGap = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = instance.status;
    final isDone = status == TaskStatus.done;

    // 计时中才订阅秒级时钟：每秒重建一次 → 秒数真的在跳（P0-3）。
    // 非计时状态不订阅，避免整列表无意义地每秒重建。
    final tick = status == TaskStatus.inProgress
        ? ref.watch(taskTickerProvider).value
        : null;

    final elapsedSeconds = _elapsedSeconds(tick ?? DateTime.now());

    return Material(
      // 与 AppCard 同一套外观：浅底 + 细边框 + 卡片圆角
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDone ? null : onToggle,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.sectionHeaderGap,
            AppDimens.cardPadding,
            AppDimens.sectionHeaderGap,
          ),
          child: Row(
            children: [
              _StatusIndicator(status: status),
              const SizedBox(width: AppDimens.cardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instance.titleSnapshot,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _titleColor(status),
                        fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        // 划线颜色与文字同色，避免出现「灰字 + 黑线」
                        decorationColor: isDone ? AppColors.todo : null,
                      ),
                    ),
                    const SizedBox(height: _titleMetaGap),
                    Text(
                      _buildMeta(elapsedSeconds),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildActions(theme, isDone),
            ],
          ),
        ),
      ),
    );
  }

  /// 右侧动作区：闹钟 / 完成 / 删除。
  Widget _buildActions(ThemeData theme, bool isDone) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: alarm == null ? '设置闹钟' : '编辑闹钟',
          onPressed: onAlarm,
          icon: Icon(alarm == null ? Icons.alarm_outlined : Icons.alarm_on),
          color: alarm == null ? AppColors.todo : AppColors.active,
          iconSize: _actionIconSize,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(
            width: _actionSize,
            height: _actionSize,
          ),
        ),
        IconButton(
          // 已完成时真的不可点：onPressed 为 null + 颜色灰化（R1）
          tooltip: isDone ? '已完成' : '标记完成',
          onPressed: isDone ? null : onComplete,
          icon: Icon(isDone ? Icons.check_circle : Icons.check_circle_outline),
          color: isDone ? theme.disabledColor : AppColors.success,
          iconSize: _actionIconSize,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(
            width: _actionSize,
            height: _actionSize,
          ),
        ),
        IconButton(
          tooltip: '删除任务',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          color: theme.colorScheme.onSurfaceVariant,
          iconSize: _actionIconSize,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(
            width: _actionSize,
            height: _actionSize,
          ),
        ),
      ],
    );
  }

  /// 标题颜色：进行中主题蓝，已完成淡化（划线在 [build] 里加）。
  Color? _titleColor(TaskStatus status) => switch (status) {
    TaskStatus.todo => null,
    TaskStatus.inProgress => AppColors.active,
    TaskStatus.done => AppColors.todo,
  };

  /// 元信息：计时中 · 类型 · 闹钟 · 已耗时（无内容的分段自动省略）。
  ///
  /// 计时中显示 `已计时 HH:MM:SS`（P0-3 的验收文案），
  /// 其它状态显示紧凑的 `耗时 12m30s`。
  String _buildMeta(int elapsedSeconds) {
    final isRunning = instance.status == TaskStatus.inProgress;
    final typeLabel = instance.typeSnapshot == TaskType.fitness ? '健身' : '学习';
    final parts = <String>[
      if (isRunning) '已计时 ${formatClock(elapsedSeconds)}',
      typeLabel,
      if (alarm != null)
        '闹钟 ${alarm!.timeLabel} · ${_repeatLabel(alarm!.repeatRule)}',
      // 0 秒不显示，避免每个新任务都挂一个「耗时 0s」
      if (!isRunning && elapsedSeconds > 0)
        '耗时 ${_formatDuration(elapsedSeconds)}',
    ];
    return parts.join(' · ');
  }

  /// 已耗时 = 已归档秒数 + 本次进行中的秒数。
  ///
  /// [TaskInstance] 没有 `totalSeconds` 字段，只有 `accumulatedSeconds`
  /// （完成/取消时归档）与 `startedAt`（进行中才有），这里做等价合成。
  ///
  /// `now` 由外部传入（计时中用每秒一跳的 tick），这样「同一个 now 算出同一个值」，
  /// 也让计时逻辑可以脱开真实时钟做确定性测试。
  int _elapsedSeconds(DateTime now) {
    var seconds = instance.accumulatedSeconds;
    final startedAt = instance.startedAt;
    if (instance.status == TaskStatus.inProgress && startedAt != null) {
      seconds += now.difference(startedAt).inSeconds;
    }
    return seconds < 0 ? 0 : seconds;
  }

  /// 秒 → `00:03:21`（计时中的展示形态：位数固定，跳动时不会左右抖）。
  static String formatClock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final restSeconds = s % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${restSeconds.toString().padLeft(2, '0')}';
  }

  /// 秒 → `45s` / `12m30s` / `1h05m`。
  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final restSeconds = seconds % 60;
    if (minutes < 60) {
      return restSeconds == 0 ? '${minutes}m' : '${minutes}m${restSeconds}s';
    }
    final hours = minutes ~/ 60;
    final restMinutes = minutes % 60;
    return restMinutes == 0
        ? '${hours}h'
        : '${hours}h${restMinutes.toString().padLeft(2, '0')}m';
  }

  static String _repeatLabel(String rule) => switch (rule) {
    'once' => '单次',
    'weekly' => '每周',
    _ => '每日',
  };
}

/// 左侧状态指示：todo 空心圆 / inProgress 蓝环 + 计时点 / done 绿勾。
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TaskTile._indicatorSize,
      height: TaskTile._indicatorSize,
      child: switch (status) {
        TaskStatus.todo => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.todo,
              width: TaskTile._ringWidth,
            ),
          ),
        ),
        TaskStatus.inProgress => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.active.withValues(alpha: 0.10),
            border: Border.all(
              color: AppColors.active,
              width: TaskTile._ringWidth,
            ),
          ),
          child: Center(
            child: Container(
              width: TaskTile._runningDotSize,
              height: TaskTile._runningDotSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.active,
              ),
            ),
          ),
        ),
        TaskStatus.done => const Icon(
          Icons.check_circle_rounded,
          size: TaskTile._indicatorSize,
          color: AppColors.success,
        ),
      },
    );
  }
}
