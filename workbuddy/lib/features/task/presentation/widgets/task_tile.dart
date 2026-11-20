import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../alarm/domain/scheduled_alarm.dart';
import '../../domain/task_enums.dart';
import '../../domain/task_instance.dart';
import '../../providers/task_ticker_provider.dart';

/// 任务条目：一张卡承载「状态指示 + 标题 + 元信息 + 动作区 + 计时控制条」。
///
/// 交互契约：
/// - 点击卡体：todo → 开始计时；已开始（计时中 / 暂停）→ 无动作
///   （**不再**「点一下取消」：取消是不可撤销的时间清零动作，必须走显式按钮）
/// - 计时控制条（仅进行中出现的第二行）：
///   - 计时中 → `暂停` + `取消计时`
///   - 已暂停 → `继续` + `取消计时`
/// - 长按卡体：仅已完成时可用，弹出「标记为未完成」菜单（UNDO-COMPLETE）
/// - 完成按钮：未完成 / 进行中可用；**已完成时 `onPressed: null` 并灰化**
/// - 闹钟按钮：始终可点（已完成的任务仍允许编辑闹钟）
/// - 删除按钮：沿用原有入口，点击后由调用方弹确认框
///
/// 计时（P0-3 / PHONE-FIX-1）：只有 `inProgress` **且** `startedAt != null` 时才
/// 订阅 [taskTickerProvider] 每秒重建；暂停后不再订阅，秒数当场冻住。
class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.instance,
    required this.onToggle,
    required this.onComplete,
    required this.onDelete,
    required this.onAlarm,
    this.onPause,
    this.onResume,
    this.onCancelTimer,
    this.alarm,
    this.onLongPress,
  });

  final TaskInstance instance;

  /// 开始计时（仅 todo 使用；已开始时卡体不再响应点击）
  final VoidCallback onToggle;

  /// 暂停（计时中）
  final VoidCallback? onPause;

  /// 继续（已暂停）
  final VoidCallback? onResume;

  /// 取消计时（回到未开始，已跑秒数仍归档）
  final VoidCallback? onCancelTimer;

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

    // R5：**不在卡片这一层订阅秒表**。
    //
    // 旧写法在这里 `ref.watch(taskTickerProvider)`，于是每秒把整张卡重建一遍：
    // Material + InkWell + 三个 IconButton + 整棵 Semantics 全部重算。
    // 实测「1000 条任务、其中 20 条计时中」时 >25ms 的帧从 12.3% 涨到 65.8%
    // —— 比列表长度本身贵得多。
    //
    // 现在只有下面那个 `_MetaLine` 订阅秒表：每秒重建的从「一整张卡」缩到
    // 「一行文字」，视觉与文案完全不变（见 _MetaLine 注释）。
    //
    // 非运行态不需要任何时钟：`_MetaLine` 内部会直接读 `DateTime.now()` 算一次。
    return Material(
      // 与 AppCard 同一套外观：浅底 + 细边框 + 卡片圆角
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // 只有「未开始」点整行才有意义（= 开始计时）。
        // 计时中 / 暂停时整行不可点：那一刻用户的意图是「暂停」或「继续」，
        // 让整行去承担某个方向的切换都会有半的人是反向结果。
        onTap: status == TaskStatus.todo ? onToggle : null,
        onLongPress: onLongPress,
        // R3：**关掉** InkWell 自己的语义，把「点击 = 开始计时」挪到下面那个
        // 合并好的文字节点上。否则语义树里会多出一个「有 tap 动作、却没有任何
        // 文字」的节点 —— 读屏停在它上面只会念一句「双击激活」，什么信息都没有。
        excludeFromSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.sectionHeaderGap,
            AppDimens.cardPadding,
            AppDimens.sectionHeaderGap,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // R3 无障碍：状态圆点 + 标题 + 元信息合并成**一个**读屏焦点，
                  // 一句念完「未开始 · 买牛奶 · 学习」；否则 TalkBack 会先停在
                  // 一个没有文字的圆点上（听起来像卡住），再跳到标题。
                  Expanded(
                    child: MergeSemantics(
                      child: Semantics(
                        // 点击动作落在「一句完整的话」上：读屏念完
                        // 「未开始 买牛奶 学习」后双击即开始计时。
                        // 只有 todo 可点，其余状态不给假的 tap 动作。
                        button: status == TaskStatus.todo,
                        onTap: status == TaskStatus.todo ? onToggle : null,
                        onLongPress: onLongPress,
                        child: Row(
                          children: [
                            // 状态由图形表达（空心圆 / 蓝环 / 绿勾），必须补一句话，
                            // 否则读屏用户完全拿不到「这条任务到哪一步了」。
                            Semantics(
                              label: _statusLabel(status, instance.isPaused),
                              child: _StatusIndicator(
                                status: status,
                                paused: instance.isPaused,
                              ),
                            ),
                            const SizedBox(width: AppDimens.cardGap),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    instance.titleSnapshot,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: _titleColor(status),
                                          fontWeight: isDone
                                              ? FontWeight.w400
                                              : FontWeight.w600,
                                          decoration: isDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                          // 划线颜色与文字同色，避免出现「灰字 + 黑线」
                                          decorationColor: isDone
                                              ? AppColors.todo
                                              : null,
                                        ),
                                  ),
                                  const SizedBox(height: _titleMetaGap),
                                  _MetaLine(
                                    instance: instance,
                                    alarm: alarm,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildActions(theme, isDone),
                ],
              ),
              // 计时中 / 已暂停：独立一行控制条（⏸/▶ + ⏹）。
              // 不塞进右上角那排 48dp 图标里 —— 那里已经三个按钮，
              // 再挤一个会把标题压到 120dp 以内（UI 提案实测 173dp 已很紧）。
              if (status == TaskStatus.inProgress) ...[
                const SizedBox(height: 4),
                _TimerControls(
                  title: instance.titleSnapshot,
                  running: instance.isRunning,
                  onPause: onPause,
                  onResume: onResume,
                  onCancel: onCancelTimer,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 右侧动作区：闹钟 / 完成 / 删除。
  ///
  /// R3 无障碍：三个按钮都是**纯图标**，光有 tooltip「标记完成」读屏用户不知道
  /// 完成的是哪一条 —— 一排三条任务时只能靠猜。这里同时给两样东西：
  /// - `label`（`Semantics.label`）：TalkBack / uiautomator 读的是这个，
  ///   **带任务名**；
  /// - `tooltip`：留着给长按看提示的视力用户。
  ///
  /// 为什么不是只给 tooltip：Flutter 把 tooltip 映射到 `tooltipText` 而不是
  /// `contentDescription`，读屏软件在部分机型上只念「按钮」，等于没标。
  Widget _buildActions(ThemeData theme, bool isDone) {
    final title = instance.titleSnapshot;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TileAction(
          label: alarm == null ? '给「$title」设置闹钟' : '编辑「$title」的闹钟',
          tooltip: alarm == null ? '设置闹钟' : '编辑闹钟',
          onPressed: onAlarm,
          icon: Icon(alarm == null ? Icons.alarm_outlined : Icons.alarm_on),
          color: alarm == null ? AppColors.todo : AppColors.active,
        ),
        _TileAction(
          // 已完成时真的不可点：onPressed 为 null + 颜色灰化（R1）
          label: isDone ? '「$title」已完成' : '标记完成「$title」',
          tooltip: isDone ? '已完成' : '标记完成',
          onPressed: isDone ? null : onComplete,
          icon: Icon(isDone ? Icons.check_circle : Icons.check_circle_outline),
          color: isDone ? theme.disabledColor : AppColors.success,
        ),
        _TileAction(
          label: '删除「$title」',
          tooltip: '删除任务',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  /// 状态圆点的一句话版本（读屏念的是这句，不是图形）。
  static String _statusLabel(TaskStatus status, bool paused) =>
      switch (status) {
        TaskStatus.todo => '未开始',
        TaskStatus.inProgress => paused ? '已暂停' : '计时中',
        TaskStatus.done => '已完成',
      };

  /// 标题颜色：进行中主题蓝，已完成淡化（划线在 [build] 里加）。
  Color? _titleColor(TaskStatus status) => switch (status) {
    TaskStatus.todo => null,
    TaskStatus.inProgress => AppColors.active,
    TaskStatus.done => AppColors.todo,
  };

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

/// 卡片第二行的元信息文字（类型 / 闹钟 / 已计时）。
///
/// **为什么单独抽一层（R5）**：秒表每秒跳一次，如果让它去重建整张卡
/// （Material + InkWell + 三个 IconButton + 整棵 Semantics），代价是「一行文字」
/// 的几十倍。把它放在这里，每秒只有这一个 `Text` 重建，卡片其余部分零重组。
///
/// 只有 `isRunning` 时才订阅 [taskTickerProvider]：
/// 暂停 / 已完成 / 未开始三种状态根本不注册订阅，秒表 provider 会自动 dispose。
/// 文案与抽出来之前逐字一致（`已计时 00:01:23` / 已暂停 / `耗时 12m30s`）。
class _MetaLine extends ConsumerWidget {
  const _MetaLine({
    required this.instance,
    required this.alarm,
    required this.style,
  });

  final TaskInstance instance;
  final ScheduledAlarm? alarm;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tick = instance.isRunning
        ? ref.watch(taskTickerProvider).value
        : null;
    final elapsed = instance.elapsedSecondsAt(tick ?? DateTime.now());

    return Text(
      _metaText(instance, alarm, elapsed),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// 纯图标动作按钮 + 真语义标签。
///
/// `excludeSemantics: true` 掉 IconButton 自己那套语义，再用 `label + onTap`
/// 重建一个节点：
/// - `label` → Android 的 `contentDescription`（`uiautomator dump` 能看到）；
/// - `onTap` → 保留「双击激活」，不然这个节点就成了「能听、按不动」；
/// - `enabled` → 禁用态（已完成）会念「不可用」，和视觉上的灰化一致。
///
/// `tooltip` 仍然保留：它服务的是长按看提示的视力用户，两套互不干扰。
class _TileAction extends StatelessWidget {
  const _TileAction({
    required this.label,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.color,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
        color: color,
        iconSize: TaskTile._actionIconSize,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: TaskTile._actionSize,
          height: TaskTile._actionSize,
        ),
      ),
    );
  }
}

/// 计时控制条：`暂停/继续` + `取消计时`。
///
/// 放在卡片第二行而不是右上角图标排里：那一排已经三个 48dp 按钮，
/// 再塞一个会把标题可用宽度压到 120dp 以内（UI 提案实测 173dp 已经很紧）。
/// 第二行整行可用，按钮带文字，比纯图标更不容易点错方向。
class _TimerControls extends StatelessWidget {
  const _TimerControls({
    required this.title,
    required this.running,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  /// 任务名：只用于读屏标签（「暂停『买牛奶』」），不参与排版。
  final String title;
  final bool running;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // 与标题左边缘对齐（越过状态圆点）
      padding: const EdgeInsets.only(
        left: TaskTile._indicatorSize + AppDimens.cardGap,
      ),
      // Wrap 而不是 Row：系统字号 1.3 时「暂停」+「取消计时」两个按钮的
      // 文字会一起变宽，窄屏上 Row 只能硬挤（溢出黄条）或压缩热区；
      // Wrap 在放不下时整颗按钮换行，热区尺寸不受影响。
      child: Wrap(
        spacing: AppDimens.chipGap,
        runSpacing: 4,
        children: [
          _TimerButton(
            icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: running ? '暂停' : '继续',
            // 卡片里可能同时有多条计时任务，光念「暂停」不知道暂停哪条
            semanticLabel: '${running ? '暂停' : '继续'}「$title」的计时',
            color: AppColors.active,
            filled: true,
            onTap: running ? onPause : onResume,
          ),
          _TimerButton(
            icon: Icons.stop_rounded,
            label: '取消计时',
            semanticLabel: '取消「$title」的计时',
            color: theme.colorScheme.onSurfaceVariant,
            onTap: onCancel,
          ),
        ],
      ),
    );
  }
}

/// 控制条上的单个按钮：紧凑、带文字、热区不低于 36dp。
class _TimerButton extends StatelessWidget {
  const _TimerButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  /// 读屏念的整句（含任务名）。可见文字是 [label]（「暂停」），
  /// 但读屏只念这一句 —— 否则同一屏两条计时任务根本分不清。
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.cardGap),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(label)],
    );

    final Widget button;

    if (!filled) {
      button = TextButton(style: style, onPressed: onTap, child: child);
    } else {
      // 「暂停 / 继续」是这条控制条的主动作：实心蓝底，与取消区分开
      button = TextButton(
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(
            AppColors.active.withValues(alpha: 0.12),
          ),
        ),
        onPressed: onTap,
        child: child,
      );
    }

    // `excludeSemantics: true` + 自备 `onTap`：念一句完整的标签，同时保留
    // TalkBack 的双击动作（不加 onTap 的话这个节点就变成「只能听、按不动」）。
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: button,
    );
  }
}

/// 左侧状态指示：todo 空心圆 / inProgress 蓝环 +（计时点 | 暂停符）/ done 绿勾。
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status, this.paused = false});

  final TaskStatus status;

  /// 进行中但已暂停：环内画两条竖杠，和「正在跑的小圆点」一眼能分开。
  final bool paused;

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
            color: AppColors.active.withValues(alpha: paused ? 0.04 : 0.10),
            border: Border.all(
              color: paused
                  ? AppColors.active.withValues(alpha: 0.55)
                  : AppColors.active,
              width: TaskTile._ringWidth,
            ),
          ),
          child: Center(
            child: paused
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _pauseBar(AppColors.active.withValues(alpha: 0.55)),
                      const SizedBox(width: 2),
                      _pauseBar(AppColors.active.withValues(alpha: 0.55)),
                    ],
                  )
                : Container(
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

  /// 暂停态的两条竖杠（宽度 2、高度 8）
  static Widget _pauseBar(Color color) => Container(
    width: 2,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}

/// 元信息文案：计时中 · 类型 · 闹钟 · 已耗时（无内容的分段自动省略）。
///
/// 计时中显示 `已计时 HH:MM:SS`（P0-3 的验收文案）；
/// 已暂停显示 `已暂停 · 已计时 HH:MM:SS`（数字不再跳，但值仍是真实累计）；
/// 其它状态显示紧凑的 `耗时 12m30s`。
///
/// 抽成顶层函数是为了让 [_MetaLine] 能复用同一段文案逻辑（R5 收窄秒表订阅）。
String _metaText(TaskInstance instance, ScheduledAlarm? alarm, int elapsed) {
  final running = instance.isRunning;
  final paused = instance.isPaused;
  final typeLabel = instance.typeSnapshot == TaskType.fitness ? '健身' : '学习';
  final parts = <String>[
    if (running) '已计时 ${TaskTile.formatClock(elapsed)}',
    if (paused) '已暂停 · 已计时 ${TaskTile.formatClock(elapsed)}',
    typeLabel,
    if (alarm != null)
      '闹钟 ${alarm.timeLabel} · ${TaskTile._repeatLabel(alarm.repeatRule)}',
    // 0 秒不显示，避免每个新任务都挂一个「耗时 0s」
    if (!running && !paused && elapsed > 0)
      '耗时 ${TaskTile._formatDuration(elapsed)}',
  ];
  return parts.join(' · ');
}
