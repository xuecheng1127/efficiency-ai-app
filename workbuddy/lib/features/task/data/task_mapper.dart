import '../../../core/database/app_database.dart';
import '../domain/task_enums.dart';
import '../domain/task_instance.dart';
import '../domain/task_template.dart';

/// Drift row ↔ Domain 实体 映射。
///
/// 隔离点：Domain 层只认识 [TaskTemplate] / [TaskInstance]（纯 Dart），
/// 不认识 Drift 生成的 row 类（TaskTemplateRow / TaskInstanceRow）。
class TaskMapper {
  static TaskTemplate toTemplate(TaskTemplateRow row) {
    return TaskTemplate(
      id: row.id,
      type: TaskType.values.byName(row.type),
      title: row.title,
      repeatMode: RepeatMode.values.byName(row.repeatMode),
      repeatDays: _parseRepeatDays(row.repeatDays),
      startDate: row.startDate,
      endDate: row.endDate,
      reminderMinutesBefore: row.reminderMinutesBefore,
      alarmEnabled: row.alarmEnabled,
      alarmConfigJson: row.alarmConfigJson,
      caloriePerMinute: row.caloriePerMinute,
      archivedAt: row.archivedAt,
      createdAt: row.createdAt,
    );
  }

  static TaskInstance toInstance(TaskInstanceRow row) {
    return TaskInstance(
      id: row.id,
      templateId: row.templateId,
      occurrenceDate: row.occurrenceDate,
      titleSnapshot: row.titleSnapshot,
      typeSnapshot: TaskType.values.byName(row.typeSnapshot),
      caloriePerMinuteSnapshot: row.caloriePerMinuteSnapshot,
      status: TaskStatus.values.byName(row.status),
      startedAt: row.startedAt,
      accumulatedSeconds: row.accumulatedSeconds,
      completedAt: row.completedAt,
      deletedAt: row.deletedAt,
    );
  }

  /// "1,3,5" → [1, 3, 5]；空/null → []
  static List<int> _parseRepeatDays(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];
    return csv.split(',').map((s) => int.parse(s.trim())).toList();
  }
}
