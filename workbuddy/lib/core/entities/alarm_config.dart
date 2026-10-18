import 'package:freezed_annotation/freezed_annotation.dart';

part 'alarm_config.freezed.dart';
part 'alarm_config.g.dart';

/// 任务闹钟配置（freezed 不可变实体，以 JSON 字符串存于任务表 alarmConfig 字段）。
///
/// 动态 JSON 结构统一用 freezed + json_serializable 生成，
/// 表内固定字段则直接使用 Drift 生成的不可变 row，避免重复定义。
@freezed
abstract class AlarmConfig with _$AlarmConfig {
  const factory AlarmConfig({
    /// 是否启用
    @Default(true) bool enabled,

    /// 提醒时间 HH:mm
    @Default('09:00') String time,

    /// 提前 15 分钟提醒
    @Default(false) bool advance15,

    /// 提前 30 分钟提醒
    @Default(false) bool advance30,

    /// 贪睡最大次数（最多 3 次）
    @Default(3) int maxSnooze,

    /// 铃音 id（内置 3-5 首轻柔纯音乐 / 本地音频路径）
    @Default('default') String sound,
  }) = _AlarmConfig;

  factory AlarmConfig.fromJson(Map<String, dynamic> json) =>
      _$AlarmConfigFromJson(json);
}
