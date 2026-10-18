import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// 设置存储 Key
abstract final class SettingsKeys {
  static const String settings = 'app_settings_v1';
}

/// 全局设置 Provider（Riverpod AsyncNotifier）
///
/// 统一使用 AsyncValue 处理异步状态：
/// - 持久化到 SharedPreferences（轻量键值，适合设置项）；
/// - 提供 [setThemeMode] 供全局一键切换；
/// - 保存/恢复不可变状态类 [AppSettings]。
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    // 初始加载：从本地读取，无则使用默认值
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(SettingsKeys.settings);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 数据损坏时回退默认值，避免崩溃
      return const AppSettings();
    }
  }

  /// 持久化当前设置
  Future<void> _persist(AppSettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SettingsKeys.settings,
      jsonEncode(next.toJson()),
    );
  }

  /// 切换主题模式（浅色/深色/跟随系统）
  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _persist(current.copyWith(themeMode: mode));
  }

  /// 设置任务提醒总开关
  Future<void> setTaskReminderEnabled(bool enabled) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _persist(current.copyWith(taskReminderEnabled: enabled));
  }

  /// 设置默认重复规则
  Future<void> setDefaultRepeatRule(int rule) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _persist(current.copyWith(defaultRepeatRule: rule));
  }

  /// 设置闹钟铃音
  Future<void> setAlarmRingtone(String ringtone) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _persist(current.copyWith(alarmRingtone: ringtone));
  }

  /// 设置闹钟音量
  Future<void> setAlarmVolume(int volume) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _persist(current.copyWith(alarmVolume: volume));
  }

  /// 设置贪睡开关
  Future<void> setSnoozeEnabled(bool enabled) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _persist(current.copyWith(snoozeEnabled: enabled));
  }

  /// 设置贪睡间隔（分钟）
  Future<void> setSnoozeMinutes(int minutes) async {
    final current = state.valueOrNull ?? const AppSettings();
    await _persist(current.copyWith(snoozeMinutes: minutes));
  }
}

/// 全局设置 Provider
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
