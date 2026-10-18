/// 任务类型：健身计划与学习任务共用一套底层能力，通过此类型区分。
enum TaskType {
  /// 健身
  fitness,

  /// 学习
  study,
}

/// 任务三态（对应需求文档「三态视觉与流转」）。
enum TaskStatus {
  /// 未完成：灰色文字、无标记
  todo,

  /// 进行中：蓝色高亮、计时状态标识
  inProgress,

  /// 已完成：绿色打勾、文字划线
  done,
}

/// 任务重复模式。
enum RepeatMode {
  /// 单次
  once,

  /// 每日重复（凌晨自动生成当日新任务）
  daily,

  /// 每周固定日重复
  weekly,
}
