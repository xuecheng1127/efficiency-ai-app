import 'task_enums.dart';

/// 任务实例（Domain 实体，纯 Dart，零 Drift 依赖）。
///
/// 描述「某天的事实」：当日可操作、独立计时、独立完成状态。
class TaskInstance {
  const TaskInstance({
    required this.id,
    required this.templateId,
    required this.occurrenceDate,
    required this.titleSnapshot,
    required this.typeSnapshot,
    this.caloriePerMinuteSnapshot,
    required this.status,
    this.startedAt,
    required this.accumulatedSeconds,
    this.completedAt,
    this.deletedAt,
  });

  final int id;
  final int templateId;
  final DateTime occurrenceDate;
  final String titleSnapshot;
  final TaskType typeSnapshot;
  final double? caloriePerMinuteSnapshot;
  final TaskStatus status;

  /// 计时唯一真源（进程被杀后据此重算，见 ADR-006）。
  final DateTime? startedAt;

  final int accumulatedSeconds;
  final DateTime? completedAt;
  final DateTime? deletedAt;

  /// 计时中：进行中**且**有 `startedAt`（秒表在跑）。
  bool get isRunning => status == TaskStatus.inProgress && startedAt != null;

  /// 已暂停：进行中但 `startedAt` 为空。
  ///
  /// 暂停态**不新增 status 值**（PHONE-FIX-1 约束）：`inProgress + startedAt == null`
  /// 这一个组合就足以表达「这段任务已经开始过，但秒表现在停着」，
  /// 归档秒数仍留在 [accumulatedSeconds] 里。
  bool get isPaused => status == TaskStatus.inProgress && startedAt == null;

  /// 已耗时（秒）= 归档秒数 + 本段正在跑的秒数。
  ///
  /// [now] 由调用方注入：计时中用每秒一跳的 tick，暂停时用任意值结果都相同，
  /// 因此测试可以脱开真实时钟做确定性断言。
  int elapsedSecondsAt(DateTime now) {
    var seconds = accumulatedSeconds;
    final start = startedAt;
    if (status == TaskStatus.inProgress && start != null) {
      final delta = now.difference(start).inSeconds;
      // 时钟被回拨（用户改时间）时 delta 为负：只忽略这一段，不拿它去啃已归档的秒数
      if (delta > 0) seconds += delta;
    }
    return seconds < 0 ? 0 : seconds;
  }
}
