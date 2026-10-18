import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

/// 全局设置状态（freezed 不可变状态类）
///
/// 需求文档「模块5：全局设置」：
/// - 主题模式：浅色 / 深色 / 跟随系统，全局一键切换；
/// - 任务提醒总开关；
/// - 默认重复规则等。
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    /// 主题模式（默认跟随系统）
    @Default(ThemeMode.system) ThemeMode themeMode,

    /// 任务提醒总开关（默认开启）
    @Default(true) bool taskReminderEnabled,

    /// 新任务默认重复规则（0=单次 1=每日 2=每周）
    @Default(0) int defaultRepeatRule,

    /// 闹钟铃音名称
    @Default('内置·晨曦') String alarmRingtone,

    /// 闹钟音量（0-100）
    @Default(80) int alarmVolume,

    /// 贪睡模式开关
    @Default(true) bool snoozeEnabled,

    /// 贪睡间隔（分钟）
    @Default(5) int snoozeMinutes,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}
