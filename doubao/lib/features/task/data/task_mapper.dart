import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/task_enums.dart';
import '../domain/task_instance.dart';
import '../domain/task_template.dart';

/// Drift row ↔ Domain 实体映射（T01 规格 §10.3）
///
/// 红线 4：Domain 实体禁止直接使用 Drift row 类，必须经本 Mapper 转换，
/// 保证 Domain 层零数据库依赖（依赖倒置）。
class TaskMapper {
  TaskMapper._();

  /// 字符串 → 枚举（数据非法时回退默认值，避免崩溃）
  static T _enumByName<T extends Enum>(List<T> values, String name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  /// Row → TaskTemplate（模板实体）
  static TaskTemplate toTemplate(TaskTemplateRow row) {
    return TaskTemplate(
      id: row.id,
      type: _enumByName(TaskType.values, row.type, TaskType.study),
      title: row.title,
      repeatMode: _enumByName(RepeatRule.values, row.repeatMode, RepeatRule.once),
      repeatDays: _parseRepeatDays(row.repeatDays),
      startDate: row.startDate,
      endDate: row.endDate,
      reminderMinutesBefore: row.reminderMinutesBefore,
      alarmEnabled: row.alarmEnabled == 1,
      alarmConfigJson: row.alarmConfigJson,
      caloriePerMinute: row.caloriePerMinute,
      archivedAt: row.archivedAt,
      createdAt: row.createdAt,
    );
  }

  /// Row → TaskInstance（实例实体）
  static TaskInstance toInstance(TaskInstanceRow row) {
    return TaskInstance(
      id: row.id,
      templateId: row.templateId,
      occurrenceDate: row.occurrenceDate,
      titleSnapshot: row.titleSnapshot,
      typeSnapshot:
          _enumByName(TaskType.values, row.typeSnapshot, TaskType.study),
      caloriePerMinuteSnapshot: row.caloriePerMinuteSnapshot,
      status: _enumByName(TaskStatus.values, row.status, TaskStatus.todo),
      startedAt: row.startedAt,
      accumulatedSeconds: row.accumulatedSeconds,
      completedAt: row.completedAt,
      deletedAt: row.deletedAt,
    );
  }

  /// TaskTemplate → Row（写入时组装；id 由库分配时传 null）
  static TaskTemplatesCompanion toTemplateCompanion(TaskTemplate t) {
    return TaskTemplatesCompanion.insert(
      type: t.type.name,
      title: t.title,
      repeatMode: t.repeatMode.name,
      repeatDays: Value(t.repeatDays.isEmpty ? null : t.repeatDays.join(',')),
      startDate: t.startDate,
      endDate: Value(t.endDate),
      reminderMinutesBefore: Value(t.reminderMinutesBefore),
      alarmEnabled: Value(t.alarmEnabled ? 1 : 0),
      alarmConfigJson: Value(t.alarmConfigJson),
      caloriePerMinute: Value(t.caloriePerMinute),
      archivedAt: Value(t.archivedAt),
      createdAt: t.createdAt,
    );
  }

  /// TaskTemplate → Row（更新已有模板；id 必须存在）
  static TaskTemplatesCompanion toTemplateUpdateCompanion(TaskTemplate t) {
    return TaskTemplatesCompanion(
      id: Value(t.id!),
      type: Value(t.type.name),
      title: Value(t.title),
      repeatMode: Value(t.repeatMode.name),
      repeatDays: Value(t.repeatDays.isEmpty ? null : t.repeatDays.join(',')),
      startDate: Value(t.startDate),
      endDate: Value(t.endDate),
      reminderMinutesBefore: Value(t.reminderMinutesBefore),
      alarmEnabled: Value(t.alarmEnabled ? 1 : 0),
      alarmConfigJson: Value(t.alarmConfigJson),
      caloriePerMinute: Value(t.caloriePerMinute),
      archivedAt: Value(t.archivedAt),
      createdAt: Value(t.createdAt),
    );
  }

  /// 新实例插入用的 Companion（快照来自模板，status=todo，累计=0）
  static TaskInstancesCompanion toInstanceCompanion(
    TaskTemplate template,
    DateTime occurrenceDate,
  ) {
    return TaskInstancesCompanion.insert(
      templateId: template.id!,
      occurrenceDate: occurrenceDate,
      titleSnapshot: template.title,
      typeSnapshot: template.type.name,
      caloriePerMinuteSnapshot: Value(template.caloriePerMinute),
      status: TaskStatus.todo.name,
      accumulatedSeconds: const Value(0),
    );
  }

  /// CSV "1,3,5" → [1, 3, 5]（1=周一 … 7=周日）；空/非法项安全跳过
  static List<int> _parseRepeatDays(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];
    final result = <int>[];
    for (final part in csv.split(',')) {
      final day = int.tryParse(part.trim());
      if (day != null && day >= 1 && day <= 7) {
        result.add(day);
      }
    }
    return result;
  }
}
