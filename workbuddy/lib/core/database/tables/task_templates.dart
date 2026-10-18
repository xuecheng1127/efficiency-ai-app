import 'package:drift/drift.dart';

/// 任务模板表：描述「规则」——每日/每周重复的抽象规则（见 T01 规格 §2.1）。
///
/// 用 [DataClassName] 把 Drift 生成的 row 类命名为 `TaskTemplateRow`，
/// 避免与 Domain 层纯 Dart 实体 `TaskTemplate` 命名冲突（禁止 Domain 直接用 Drift row）。
@DataClassName('TaskTemplateRow')
class TaskTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 任务类型：fitness | study
  TextColumn get type => text().withLength(min: 1, max: 16)();

  /// 标题（长度 1–200）
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// 重复模式：once | daily | weekly
  TextColumn get repeatMode => text().withLength(min: 1, max: 16)();

  /// 仅 weekly："1,3,5"（1=周一 … 7=周日，Dart 语义）
  TextColumn get repeatDays => text().nullable()();

  /// 生效起始日（once 时即执行日）
  DateTimeColumn get startDate => dateTime()();

  /// NULL = 无限
  DateTimeColumn get endDate => dateTime().nullable()();

  /// 提前提醒分钟数：15 / 30；NULL = 不提醒
  IntColumn get reminderMinutesBefore => integer().nullable()();

  /// 闹钟开关（0/1，底层 INTEGER）
  BoolColumn get alarmEnabled => boolean().withDefault(const Constant(false))();

  /// 铃声、渐强、贪睡次数等（JSON）
  TextColumn get alarmConfigJson => text().nullable()();

  /// 仅 fitness：千卡/分钟
  RealColumn get caloriePerMinute => real().nullable()();

  /// 模板级软删除（停止重复，保留历史实例）
  DateTimeColumn get archivedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
