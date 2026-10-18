import 'package:drift/drift.dart';

import 'task_templates.dart';

/// 闹钟持久化表（T10）。
///
/// 背景：此前闹钟的全部调度参数只活在运行时（Intent / 内存）里，进程重建或设备重启
/// 后拿不到参数，无法重建闹钟（见 `评审-闹钟模块-实现对照.md` 第一节）。
/// 本表把调度参数落盘，作为闹钟的**唯一真源**。
///
/// 设计要点：
/// - **不依赖任何 Intent**：T11 只需 `select * from scheduled_alarms where enabled = 1`
///   即可独立回答「有哪些闹钟要重建」。
/// - **一个任务至多一条记录**：`task_id` 上加 UNIQUE，配合仓库层「先删后插」的写入语义，
///   结构上杜绝重复闹钟记录。
/// - **级联**：`task_id` 外键指向 `task_templates(id)` 且 `ON DELETE CASCADE`，
///   任务被硬删除时闹钟记录自动清理；归档（`archivedAt` 软删）由仓库层显式处理。
/// - **档位区分**：`tier` 承载 A 精确 / B 近似 / C 应用内三档，供 T12 维护与 UI 展示。
/// - 例外：`weekdays` 使用 Dart `DateTime.weekday` 语义（1=周一 … 7=周日），
///   禁止使用 `Calendar.DAY_OF_WEEK`（1=周日）语义。
@DataClassName('ScheduledAlarmRow')
class ScheduledAlarms extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 关联任务模板 id（本工程双层模型里「绑定闹钟」落在模板粒度）。
  /// UNIQUE：一个任务至多一条持久化闹钟记录。
  IntColumn get taskId => integer().unique().references(
    TaskTemplates,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// 提醒时刻：小时 0–23
  IntColumn get hour => integer()();

  /// 提醒时刻：分钟 0–59
  IntColumn get minute => integer()();

  /// 重复规则：once | daily | weekly
  TextColumn get repeatRule => text().withLength(min: 1, max: 16)();

  /// 仅 weekly："1,3,5"（1=周一 … 7=周日，Dart 语义）；其余为 NULL
  TextColumn get weekdays => text().nullable()();

  /// 仅 once 有意义：具体执行日（dateOnly，时分为 0）。
  /// 写入时 once 一律落成具体日期（未指定则取当天），重复任务通常为 NULL。
  DateTimeColumn get scheduledDate => dateTime().nullable()();

  /// 提前提醒分钟数：15 / 30；NULL = 不提前
  IntColumn get advanceMinutes => integer().nullable()();

  /// 铃音 id（内置曲目 id 或本地音频路径）
  TextColumn get ringtone => text().withDefault(const Constant('default'))();

  /// 音量百分比 0–100
  IntColumn get volume => integer().withDefault(const Constant(80))();

  /// 贪睡开关
  BoolColumn get snoozeEnabled => boolean().withDefault(const Constant(true))();

  /// 贪睡间隔（分钟）
  IntColumn get snoozeMinutes => integer().withDefault(const Constant(5))();

  /// 当前档位：exact（A 精确档）| inexact（B 近似档）| inApp（C 应用内档）。
  /// T10 只负责「能存能读」，档位的判定与重排属于 T12。
  TextColumn get tier => text().withDefault(const Constant('inexact'))();

  /// 是否参与重建（关掉提醒 = 0，记录保留以便用户回看）。
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
