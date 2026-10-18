/// 任务体系枚举定义（T01 规格 §10.3：保留，纯 Dart 无依赖）
/// 需求文档「模块1：任务体系」核心概念。

/// 任务类型：健身计划与学习任务共用一套底层能力，通过类型字段区分
enum TaskType {
  /// 健身计划
  fitness('健身'),

  /// 学习任务
  study('学习');

  const TaskType(this.label);
  final String label;
}

/// 任务周期与重复规则（对应 task_templates.repeatMode：once|daily|weekly）
enum RepeatRule {
  /// 单次
  once('单次'),

  /// 每日重复
  daily('每日重复'),

  /// 每周固定日重复
  weekly('每周重复');

  const RepeatRule(this.label);
  final String label;
}

/// 任务三态（需求：未完成/进行中/已完成）
enum TaskStatus {
  /// 未完成：灰色文字、无标记
  todo('未完成'),

  /// 进行中：蓝色高亮、计时状态标识
  inProgress('进行中'),

  /// 已完成：绿色打勾、文字划线
  done('已完成');

  const TaskStatus(this.label);
  final String label;
}

/// 每周固定日（1=周一 ... 7=周日，Dart DateTime.weekday 语义）
enum Weekday {
  monday('周一', 1),
  tuesday('周二', 2),
  wednesday('周三', 3),
  thursday('周四', 4),
  friday('周五', 5),
  saturday('周六', 6),
  sunday('周日', 7);

  const Weekday(this.label, this.value);
  final String label;
  final int value;

  /// 根据 DateTime.weekday（1=周一...7=周日）查找对应枚举
  static Weekday fromDateTime(int weekday) =>
      Weekday.values.firstWhere((w) => w.value == weekday);
}
