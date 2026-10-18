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
}
