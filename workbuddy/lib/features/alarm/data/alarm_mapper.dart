import '../../../core/database/app_database.dart';
import '../domain/alarm_enums.dart';
import '../domain/scheduled_alarm.dart';

/// Drift row ↔ Domain 实体 映射（隔离点：Domain 不认识 Drift 生成的 row 类）。
class AlarmMapper {
  static ScheduledAlarm toDomain(ScheduledAlarmRow row) {
    return ScheduledAlarm(
      id: row.id,
      taskId: row.taskId,
      hour: row.hour,
      minute: row.minute,
      repeatRule: row.repeatRule,
      weekdays: decodeWeekdays(row.weekdays),
      scheduledDate: row.scheduledDate,
      advanceMinutes: row.advanceMinutes,
      ringtone: row.ringtone,
      volume: row.volume,
      snoozeEnabled: row.snoozeEnabled,
      snoozeMinutes: row.snoozeMinutes,
      tier: AlarmTier.parse(row.tier),
      enabled: row.enabled,
    );
  }

  /// "1,3,5" → [1, 3, 5]；空 / null → []（与 TaskMapper 的周一为 1 语义一致）
  static List<int> decodeWeekdays(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];
    return csv
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList()
      ..sort();
  }

  /// [1, 3, 5] → "1,3,5"；空 → null
  static String? encodeWeekdays(List<int> days) {
    if (days.isEmpty) return null;
    final sorted = [...days]..sort();
    return sorted.join(',');
  }
}
