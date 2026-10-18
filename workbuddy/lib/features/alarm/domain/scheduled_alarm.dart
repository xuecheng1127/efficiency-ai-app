import 'alarm_enums.dart';

/// 闹钟持久化记录（Domain 实体，纯 Dart，零 Drift 依赖）。
///
/// 字段与 T10 规格要求的 11 项一一对应：
/// taskId / hour / minute / repeatRule / weekdays / scheduledDate /
/// advanceMinutes / ringtone / volume / snoozeEnabled / snoozeMinutes。
class ScheduledAlarm {
  const ScheduledAlarm({
    required this.id,
    required this.taskId,
    required this.hour,
    required this.minute,
    required this.repeatRule,
    this.weekdays = const [],
    this.scheduledDate,
    this.advanceMinutes,
    this.ringtone = 'default',
    this.volume = 80,
    this.snoozeEnabled = true,
    this.snoozeMinutes = 5,
    this.tier = AlarmTier.inexact,
    this.enabled = true,
  });

  final int id;

  /// 关联任务（本工程为 task_templates.id）
  final int taskId;

  final int hour;
  final int minute;

  /// once | daily | weekly（与 [RepeatMode] 同名，用字符串存避免跨层枚举耦合）
  final String repeatRule;

  /// 仅 weekly 有意义：1=周一 … 7=周日（Dart `DateTime.weekday` 语义）
  final List<int> weekdays;

  /// 仅 once 有意义：具体执行日
  final DateTime? scheduledDate;

  /// 提前提醒分钟数（15 / 30）；null = 不提前
  final int? advanceMinutes;

  final String ringtone;

  /// 音量百分比 0–100
  final int volume;

  final bool snoozeEnabled;
  final int snoozeMinutes;

  final AlarmTier tier;

  /// 是否参与重建（T11 的「有哪些闹钟要重建」）
  final bool enabled;

  /// 下一次触发时刻（纯函数，供原生调度与 T11 重建使用）。
  ///
  /// 注意：这里只做「时间点推算」，不涉及任何触发/降级逻辑（那属于 T11+）。
  DateTime nextTriggerAt(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    switch (repeatRule) {
      case 'once':
        final d = scheduledDate ?? today;
        return DateTime(d.year, d.month, d.day, hour, minute);

      case 'weekly':
        final days = weekdays.toSet();
        if (days.isEmpty) {
          // weekly 但没选星期 → 退化为「每日」
          final todayAt = DateTime(
            today.year,
            today.month,
            today.day,
            hour,
            minute,
          );
          return todayAt.isAfter(now)
              ? todayAt
              : todayAt.add(const Duration(days: 1));
        }
        for (var i = 0; i <= 7; i++) {
          final candidate = DateTime(
            today.year,
            today.month,
            today.day + i,
            hour,
            minute,
          );
          if (!days.contains(candidate.weekday)) continue;
          if (candidate.isAfter(now)) return candidate;
        }
        // 理论上不会走到这里（最多 7 天内必有匹配）
        return DateTime(today.year, today.month, today.day + 7, hour, minute);

      default: // daily
        final todayAt = DateTime(
          today.year,
          today.month,
          today.day,
          hour,
          minute,
        );
        return todayAt.isAfter(now)
            ? todayAt
            : todayAt.add(const Duration(days: 1));
    }
  }

  /// 是否是「已经过去的一次性闹钟」。
  ///
  /// 判定与原生侧 `AlarmScheduler.isExpiredOnce` **刻意保持同一规则**：
  /// `repeatRule == 'once' && nextTriggerAt(now) <= now`（正好相等也算过期，两边都是 `<=`）。
  ///
  /// 两侧都需要这条规则，但**原因不同**：
  /// - 原生侧（`rescheduleAll`）：把已经过去的时刻交给 `setExactAndAllowWhileIdle`，
  ///   系统会**立刻**触发 —— 用户重启一次设备就会凭空响一声，所以必须**跳过重排**；
  /// - Dart 侧（[AlarmRepository.pruneExpiredOnce]）：这条记录再也不可能触发，
  ///   留着只会让界面显示一个假的「已设闹钟」，所以要**清理**掉。
  ///   表的所有者是 Dart，原生侧对表只读（ADR-008 / T11-7 测试）。
  ///
  /// `daily` / `weekly` 永远不会过期：[nextTriggerAt] 只返回**未来**时刻。
  bool isExpiredOnce(DateTime now) =>
      repeatRule == 'once' && !nextTriggerAt(now).isAfter(now);

  /// "07:05" 形式，便于日志与界面展示。
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  String toString() {
    return 'ScheduledAlarm(taskId: $taskId, hour: $hour, minute: $minute, '
        'repeatRule: $repeatRule, weekdays: ${weekdays.join(',')}, '
        'scheduledDate: ${scheduledDate == null ? 'null' : _dateLabel(scheduledDate!)}, '
        'advanceMinutes: ${advanceMinutes ?? 'null'}, ringtone: $ringtone, '
        'volume: $volume, snoozeEnabled: $snoozeEnabled, '
        'snoozeMinutes: $snoozeMinutes, tier: ${tier.name}, enabled: $enabled)';
  }

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
