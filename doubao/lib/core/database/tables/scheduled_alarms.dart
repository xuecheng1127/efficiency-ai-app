import 'package:drift/drift.dart';

/// 已调度闹钟持久化表（T10）
///
/// 用途：进程被杀/重启后，能从 SQLite 完整读回「有哪些闹钟需要重建」，
/// 不依赖任何 Intent（T11 开机重建的数据源）。
///
/// 11 个必须持久化的字段（inbox §T10）：
/// taskId / hour / minute / repeatRule / weekdays / scheduledDate /
/// advanceMinutes / ringtone / volume / snoozeEnabled / snoozeMinutes
@DataClassName('ScheduledAlarmRow')
class ScheduledAlarms extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 关联 task_templates.id（一个模板最多一条已调度闹钟）
  IntColumn get taskId => integer().named('task_id')();

  /// 闹钟触发时：时（0-23）
  IntColumn get hour => integer()();

  /// 闹钟触发时：分（0-59）
  IntColumn get minute => integer()();

  /// 重复规则：once / daily / weekly（存枚举 name）
  TextColumn get repeatRule => text().named('repeat_rule')();

  /// weekly 生效：固定日 CSV "1,3,5"（1=周一）；其余模式 NULL
  TextColumn get weekdays => text().nullable()();

  /// 计划触发时刻（epoch **秒**，Drift dateTime() 列统一存秒，与 task_templates.start_date 一致）
  DateTimeColumn get scheduledDate =>
      dateTime().named('scheduled_date')();

  /// 提前提醒分钟（0/15/30）
  IntColumn get advanceMinutes =>
      integer().named('advance_minute')();

  /// 铃音标识（内置名或 URI）
  TextColumn get ringtone => text()();

  /// 音量 0.0-1.0
  RealColumn get volume => real()();

  /// 是否开启贪睡
  IntColumn get snoozeEnabled =>
      integer().named('snooze_enabled').withDefault(const Constant(0))();

  /// 贪睡分钟数
  IntColumn get snoozeMinutes =>
      integer().named('snooze_minutes').withDefault(const Constant(5))();

  /// 写入时间（调试用）
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}
