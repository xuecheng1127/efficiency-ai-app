import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/task_enums.dart';
import '../../domain/task_repository.dart';
import '../../providers/task_timer_provider.dart';

/// 单个任务卡片（三态视觉与流转）
///
/// 三态规范：
/// - 未完成：灰色文字、无标记（中性灰 #9CA3AF）
/// - 进行中：蓝色高亮、计时状态标识（主题蓝 #2563EB）
/// - 已完成：绿色打勾、文字划线（柔和绿 #10B981）
///
/// 性能说明：进行中且是当前计时任务时，实时秒数由内部 Consumer
/// 每秒单独刷新（不重建整卡，避免呼吸圆点动画闪烁）。
class TaskCard extends ConsumerWidget {
  final TaskWithOccurrence item;
  final VoidCallback? onStart; // 点击开始计时
  final VoidCallback? onComplete; // 点击完成
  final VoidCallback? onReopen; // 撤销完成
  final VoidCallback? onLongPress; // 长按操作（编辑/删除）

  /// 是否正是当前计时任务（内部单独订阅 elapsedSeconds 实时刷新）
  final bool isActiveTimer;

  const TaskCard({
    super.key,
    required this.item,
    this.onStart,
    this.onComplete,
    this.onReopen,
    this.onLongPress,
    this.isActiveTimer = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occ = item.occurrence;
    final task = item.task;

    // 三态取色
    final (Color color, IconData icon) = switch (occ.status) {
      TaskStatus.todo => (AppColors.neutral, Icons.circle_outlined),
      TaskStatus.inProgress => (
          AppColors.primary,
          Icons.timer_outlined
        ),
      TaskStatus.done => (AppColors.success, Icons.check_circle),
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textDark : AppColors.textLight;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        onLongPress: onLongPress,
        // 完成态点击撤销；其他状态点击开始计时（流转逻辑）
        onTap: occ.status == TaskStatus.done
            ? onReopen
            : (occ.status == TaskStatus.inProgress
                ? onComplete
                : onStart),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 左侧：状态图标（水波纹点击区 ≥44dp）
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: occ.status == TaskStatus.done ? onReopen : onComplete,
                  icon: Icon(icon, color: color, size: 26),
                  padding: EdgeInsets.zero,
                  tooltip: occ.status == TaskStatus.done ? '撤销完成' : '完成',
                ),
              ),
              const SizedBox(width: 8),
              // 中间：标题 + 元信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: occ.status == TaskStatus.todo
                            ? AppColors.neutral
                            : (occ.status == TaskStatus.done
                                ? AppColors.neutral
                                : textColor),
                        decoration: occ.status == TaskStatus.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppColors.neutral,
                      ),
                      child: Text(
                        // 标题使用实例快照（快照原则：改模板不影响已生成实例）
                        occ.titleSnapshot,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 类型标签 + 重复规则 + 耗时（闹钟标识 T10 恢复）
                    Row(
                      children: [
                        _TypeBadge(
                          type: occ.typeSnapshot,
                          status: occ.status,
                        ),
                        const SizedBox(width: 8),
                        _RepeatLabel(repeatMode: task.repeatMode),
                        if (occ.status == TaskStatus.inProgress &&
                            isActiveTimer) ...[
                          // 当前计时任务：实时秒数由内部 Consumer 每秒刷新
                          const SizedBox(width: 8),
                          Consumer(
                            builder: (context, ref, _) {
                              final elapsed = ref.watch(
                                taskTimerProvider.select(
                                  (s) => s.elapsedSeconds,
                                ),
                              );
                              return _DurationLabel(seconds: elapsed);
                            },
                          ),
                        ] else if (occ.accumulatedSeconds > 0) ...[
                          const SizedBox(width: 8),
                          _DurationLabel(seconds: occ.accumulatedSeconds),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 右侧：进行中动画标识
              if (occ.status == TaskStatus.inProgress)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .fadeIn(duration: 600.ms, curve: Curves.easeInOut)
                    .then()
                    .fadeOut(duration: 600.ms, curve: Curves.easeInOut),
            ],
          ),
        ),
      ),
    );
  }
}

/// 类型徽标：健身 / 学习
class _TypeBadge extends StatelessWidget {
  final TaskType type;
  final TaskStatus status;

  const _TypeBadge({required this.type, required this.status});

  @override
  Widget build(BuildContext context) {
    // 已完成时徽标退色，保持"已完成优先"的视觉层级
    final color = status == TaskStatus.done
        ? AppColors.success.withValues(alpha: 0.6)
        : (type == TaskType.fitness ? AppColors.warning : AppColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 重复规则标签
class _RepeatLabel extends StatelessWidget {
  final RepeatRule repeatMode;

  const _RepeatLabel({required this.repeatMode});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.textDark : AppColors.textLight;
    return Text(
      repeatMode.label,
      style: TextStyle(
        fontSize: 12,
        color: color.withValues(alpha: 0.6),
      ),
    );
  }
}

/// 耗时标签
class _DurationLabel extends StatelessWidget {
  final int seconds;

  const _DurationLabel({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.textDark : AppColors.textLight;
    return Text(
      _format(seconds),
      style: TextStyle(
        fontSize: 12,
        color: color.withValues(alpha: 0.6),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  static String _format(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
