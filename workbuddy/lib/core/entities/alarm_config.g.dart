// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarm_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AlarmConfig _$AlarmConfigFromJson(Map<String, dynamic> json) => _AlarmConfig(
  enabled: json['enabled'] as bool? ?? true,
  time: json['time'] as String? ?? '09:00',
  advance15: json['advance15'] as bool? ?? false,
  advance30: json['advance30'] as bool? ?? false,
  maxSnooze: (json['maxSnooze'] as num?)?.toInt() ?? 3,
  sound: json['sound'] as String? ?? 'default',
);

Map<String, dynamic> _$AlarmConfigToJson(_AlarmConfig instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'time': instance.time,
      'advance15': instance.advance15,
      'advance30': instance.advance30,
      'maxSnooze': instance.maxSnooze,
      'sound': instance.sound,
    };
