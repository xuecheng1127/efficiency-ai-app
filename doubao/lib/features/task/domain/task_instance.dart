import 'task_enums.dart';

/// 任务实例领域实体（T01 规格 §2.2 / §10.3）
///
/// 纯 Dart、零 Drift 依赖（红线 4：禁止 Domain 实体直接使用 Drift row 类）。
/// 描述「某天的事实」：该日期的三态流转、计时、耗时与热量快照。
/// 快照原则（规格 2.3）：改模板不影响已生成实例。
class TaskInstance {
  /// 主键；null 表示尚未入库
  final int? id;

  /// 关联的模板 id（FK → task_templates.id）
  final int templateId;

  /// 该实例所属日期（归一化到当天 00:00:00）
  final DateTime occurrenceDate;

  /// 生成时的标题快照
  final String titleSnapshot;

  /// 生成时的类型快照
  final TaskType typeSnapshot;

  /// 生成时的热量系数快照（千卡/分钟）
  final double? caloriePerMinuteSnapshot;

  /// 当日三态：todo | inProgress | done
  final TaskStatus status;

  /// 计时唯一真源（开始计时时写入）
  final DateTime? startedAt;

  /// 已完成区段累计秒数（默认 0）
  final int accumulatedSeconds;

  /// 完成时间
  final DateTime? completedAt;

  /// 实例级软删除时间；非空 = 该天任务已删除（补齐不复活）
  final DateTime? deletedAt;

  const TaskInstance({
    this.id,
    required this.templateId,
    required this.occurrenceDate,
    required this.titleSnapshot,
    required this.typeSnapshot,
    this.caloriePerMinuteSnapshot,
    this.status = TaskStatus.todo,
    this.startedAt,
    this.accumulatedSeconds = 0,
    this.completedAt,
    this.deletedAt,
  });

  TaskInstance copyWith({
    int? id,
    int? templateId,
    DateTime? occurrenceDate,
    String? titleSnapshot,
    TaskType? typeSnapshot,
    double? caloriePerMinuteSnapshot,
    TaskStatus? status,
    DateTime? startedAt,
    bool clearStartedAt = false,
    int? accumulatedSeconds,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return TaskInstance(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      titleSnapshot: titleSnapshot ?? this.titleSnapshot,
      typeSnapshot: typeSnapshot ?? this.typeSnapshot,
      caloriePerMinuteSnapshot:
          caloriePerMinuteSnapshot ?? this.caloriePerMinuteSnapshot,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
