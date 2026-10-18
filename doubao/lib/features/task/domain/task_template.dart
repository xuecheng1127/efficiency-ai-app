import 'task_enums.dart';

/// 任务模板领域实体（T01 规格 §2.1 / §10.3）
///
/// 纯 Dart、零 Drift 依赖（红线 4：禁止 Domain 实体直接使用 Drift row 类）。
/// 描述「规则」：什么类型、什么时候重复、闹钟/热量配置等固定属性。
/// 实例化后通过 [TaskTemplate.copyWith] 生成修改版，保证不可变。
class TaskTemplate {
  /// 主键；null 表示尚未入库
  final int? id;

  /// 任务类型：fitness | study
  final TaskType type;

  /// 任务标题（1–200 字符）
  final String title;

  /// 重复模式：once | daily | weekly
  final RepeatRule repeatMode;

  /// 仅 weekly 生效：固定日（1=周一 … 7=周日），空列表 = 永不命中
  final List<int> repeatDays;

  /// 生效起始日（once 时即执行日；日期部分归一化到当天 00:00:00）
  final DateTime startDate;

  /// 结束日期；null = 无限重复
  final DateTime? endDate;

  /// 提前提醒分钟（15 / 30）；null = 不提醒
  final int? reminderMinutesBefore;

  /// 是否绑定闹钟（T01 仅存标记，调度在 T10 实现）
  final bool alarmEnabled;

  /// 闹钟配置 JSON（铃声 / 渐强 / 贪睡次数等），T10 使用
  final String? alarmConfigJson;

  /// 热量系数（千卡/分钟），仅 fitness 有值
  final double? caloriePerMinute;

  /// 模板级软删除时间；非空 = 已归档（停止重复、保留历史实例）
  final DateTime? archivedAt;

  /// 创建时间
  final DateTime createdAt;

  const TaskTemplate({
    this.id,
    required this.type,
    required this.title,
    required this.repeatMode,
    this.repeatDays = const [],
    required this.startDate,
    this.endDate,
    this.reminderMinutesBefore,
    this.alarmEnabled = false,
    this.alarmConfigJson,
    this.caloriePerMinute,
    this.archivedAt,
    required this.createdAt,
  });

  TaskTemplate copyWith({
    int? id,
    TaskType? type,
    String? title,
    RepeatRule? repeatMode,
    List<int>? repeatDays,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    int? reminderMinutesBefore,
    bool clearReminder = false,
    bool? alarmEnabled,
    String? alarmConfigJson,
    double? caloriePerMinute,
    bool clearCalorie = false,
    DateTime? archivedAt,
    bool clearArchived = false,
    DateTime? createdAt,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      repeatMode: repeatMode ?? this.repeatMode,
      repeatDays: repeatDays ?? this.repeatDays,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      reminderMinutesBefore: clearReminder
          ? null
          : (reminderMinutesBefore ?? this.reminderMinutesBefore),
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmConfigJson: alarmConfigJson ?? this.alarmConfigJson,
      caloriePerMinute:
          clearCalorie ? null : (caloriePerMinute ?? this.caloriePerMinute),
      archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
