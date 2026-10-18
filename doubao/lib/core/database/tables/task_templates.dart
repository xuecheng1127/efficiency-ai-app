import 'package:drift/drift.dart';

/// 任务模板表 —— 描述「规则」（T01 规格 §2.1，12 字段）
///
/// 与 Isar 旧模型（Task 单表）的关键差异：
/// - 拆出 `startDate` / `endDate` 取代旧 `scheduledDate`：startDate 是生效起始日，
///   `once` 时即执行日；endDate 为 NULL 表示无限重复；
/// - `repeatDays`（TEXT CSV "1,3,5"，1=周一…7=周日）取代旧 `weekdays`（List<int>）；
/// - `alarmConfigJson`（TEXT JSON）取代旧 `alarmTime` / `alarmAdvanceMinutes`，
///   闹钟绑定属 T10，T01 仅建字段不实现调度；
/// - `archivedAt`（DATETIME 可空）取代旧 `archived`（bool）：模板级软删除，
///   停止重复但保留历史实例。
@DataClassName('TaskTemplateRow')
class TaskTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 任务类型：fitness | study（存枚举 name，与规格 2.1 一致）
  TextColumn get type => text().withLength(min: 1, max: 20)();

  /// 任务标题（1–200）
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// 重复模式：once | daily | weekly（存枚举 name）
  TextColumn get repeatMode => text().withLength(min: 1, max: 10)();

  /// 仅 weekly 生效：固定日 CSV，如 "1,3,5"（1=周一 … 7=周日，Dart 语义）
  /// 空串 / NULL 表示无固定日（weekly 且 repeatDays 空 → 永不命中）
  TextColumn get repeatDays => text().nullable()();

  /// 生效起始日（归一化到当天 00:00:00；once 时即执行日）
  DateTimeColumn get startDate => dateTime()();

  /// 结束日期，NULL = 无限
  DateTimeColumn get endDate => dateTime().nullable()();

  /// 提前提醒分钟（15 / 30；NULL = 不提醒）
  IntColumn get reminderMinutesBefore => integer().nullable()();

  /// 是否绑定闹钟（0/1）。T01 仅存标记，调度在 T10 实现
  IntColumn get alarmEnabled => integer().withDefault(const Constant(0))();

  /// 闹钟配置 JSON（铃声 / 渐强 / 贪睡次数等），T10 使用
  TextColumn get alarmConfigJson => text().nullable()();

  /// 热量系数（千卡/分钟），仅 fitness 有值
  RealColumn get caloriePerMinute => real().nullable()();

  /// 模板级软删除时间（非空 = 已归档，停止重复）
  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime()();
}
