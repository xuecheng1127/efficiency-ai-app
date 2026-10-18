import 'package:drift/drift.dart';

import 'task_templates.dart';

/// 任务实例表 —— 描述「某天的事实」（T01 规格 §2.2，11 字段）
///
/// 与 Isar 旧模型（TaskOccurrence 单表）的关键差异：
/// - `templateId` FK → task_templates.id，取代旧 `taskId`；
/// - `occurrenceDate`（DATE）取代旧 `date`，并与 templateId 组成唯一索引
///   （幂等性唯一保障，红线 3）；
/// - 三个快照字段（titleSnapshot / typeSnapshot / caloriePerMinuteSnapshot）：
///   生成时从模板复制，改模板不影响已生成实例（快照原则，红线 5）；
/// - `accumulatedSeconds` 取代旧 `durationSeconds`：已完成区段累计，
///   `startedAt` 是计时唯一真源；
/// - `deletedAt`（DATETIME 可空）取代旧硬删除：实例级软删除，仅删这一天。
///
/// 约束（规格 2.3）：UNIQUE(templateId, occurrenceDate) 必须存在。
@TableIndex(
  name: 'idx_instances_template_date',
  columns: {#templateId, #occurrenceDate},
  unique: true,
)
@DataClassName('TaskInstanceRow')
class TaskInstances extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 关联模板 id（FK → task_templates.id）
  IntColumn get templateId =>
      integer().references(TaskTemplates, #id)();

  /// 该实例所属日期（归一化到当天 00:00:00）
  DateTimeColumn get occurrenceDate => dateTime()();

  /// 生成时的标题快照
  TextColumn get titleSnapshot => text().withLength(min: 1, max: 200)();

  /// 生成时的类型快照（fitness | study）
  TextColumn get typeSnapshot => text().withLength(min: 1, max: 20)();

  /// 生成时的热量系数快照
  RealColumn get caloriePerMinuteSnapshot => real().nullable()();

  /// 当日三态：todo | inProgress | done（存枚举 name）
  TextColumn get status => text().withLength(min: 1, max: 12)();

  /// 计时唯一真源（非空 = 计时进行中/曾开始过）
  DateTimeColumn get startedAt => dateTime().nullable()();

  /// 已完成区段累计秒数（默认 0）
  IntColumn get accumulatedSeconds =>
      integer().withDefault(const Constant(0))();

  /// 完成时间
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// 实例级软删除时间（非空 = 该天任务已删除，补齐不复活）
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
