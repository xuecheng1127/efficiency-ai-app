// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => _AppSettings(
      themeMode: $enumDecodeNullable(_$ThemeModeEnumMap, json['themeMode']) ??
          ThemeMode.system,
      taskReminderEnabled: json['taskReminderEnabled'] as bool? ?? true,
      defaultRepeatRule: (json['defaultRepeatRule'] as num?)?.toInt() ?? 0,
      alarmRingtone: json['alarmRingtone'] as String? ?? '内置·晨曦',
      alarmVolume: (json['alarmVolume'] as num?)?.toInt() ?? 80,
      snoozeEnabled: json['snoozeEnabled'] as bool? ?? true,
      snoozeMinutes: (json['snoozeMinutes'] as num?)?.toInt() ?? 5,
    );

Map<String, dynamic> _$AppSettingsToJson(_AppSettings instance) =>
    <String, dynamic>{
      'themeMode': _$ThemeModeEnumMap[instance.themeMode]!,
      'taskReminderEnabled': instance.taskReminderEnabled,
      'defaultRepeatRule': instance.defaultRepeatRule,
      'alarmRingtone': instance.alarmRingtone,
      'alarmVolume': instance.alarmVolume,
      'snoozeEnabled': instance.snoozeEnabled,
      'snoozeMinutes': instance.snoozeMinutes,
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};
