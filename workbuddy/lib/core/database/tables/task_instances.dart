import 'package:drift/drift.dart';

import 'task_templates.dart';

/// 任务实例表：描述「某天的事实」——当日可操作、独立计时、独立完成状态（见 T01 规格 §2.2）。
@DataClassName('TaskInstanceRow')
class TaskInstances extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 关联模板
  IntColumn get templateId => integer().references(TaskTemplates, #id)();

  /// 该实例所属日期
  DateTimeColumn get occurrenceDate => dateTime()();

  /// 生成时的标题快照
  TextColumn get titleSnapshot => text().withLength(min: 1, max: 200)();

  /// 类型快照
  TextColumn get typeSnapshot => text().withLength(min: 1, max: 16)();

  /// 热量系数快照（仅 fitness）
  RealColumn get caloriePerMinuteSnapshot => real().nullable()();

  /// 三态：todo | inProgress | done
  TextColumn get status => text().withLength(min: 1, max: 16)();

  /// 计时唯一真源
  DateTimeColumn get startedAt => dateTime().nullable()();

  /// 已完成区段累计（秒）
  IntColumn get accumulatedSeconds =>
      integer().withDefault(const Constant(0))();

  DateTimeColumn get completedAt => dateTime().nullable()();

  /// 实例级软删除
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 唯一索引：UNIQUE(templateId, occurrenceDate) —— 幂等性的唯一保障，不可省略。
  @override
  List<Set<Column>> get uniqueKeys => [
    {templateId, occurrenceDate},
  ];
}
