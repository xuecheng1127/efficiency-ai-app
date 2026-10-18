import 'task_enums.dart';

/// 任务模板（Domain 实体，纯 Dart，零 Drift 依赖）。
///
/// 描述「规则」：每日/每周重复的抽象规则。禁止直接使用 Drift 生成的 row 类，
/// Drift row ↔ 本实体 的转换由 Data 层 `task_mapper.dart` 完成（依赖倒置）。
class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.type,
    required this.title,
    required this.repeatMode,
    required this.repeatDays,
    required this.startDate,
    this.endDate,
    this.reminderMinutesBefore,
    required this.alarmEnabled,
    this.alarmConfigJson,
    this.caloriePerMinute,
    this.archivedAt,
    required this.createdAt,
  });

  final int id;
  final TaskType type;
  final String title;
  final RepeatMode repeatMode;

  /// 每周固定日（1=周一 … 7=周日）；空列表表示无（weekly 且空则恒不生成）。
  final List<int> repeatDays;

  final DateTime startDate;
  final DateTime? endDate;
  final int? reminderMinutesBefore;
  final bool alarmEnabled;
  final String? alarmConfigJson;
  final double? caloriePerMinute;
  final DateTime? archivedAt;
  final DateTime createdAt;
}
