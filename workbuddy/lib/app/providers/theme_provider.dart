import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';

/// 主题模式（浅色 / 深色 / 跟随系统），全局一键切换。
///
/// T-UI：**持久化**。之前只在内存里改 state，杀进程就回默认 ——
/// 设置页改完主题、重启又变回去，用户会认为"这个设置是假的"。
/// 现在读写 `app_settings.json` 的 `themeMode`，与设置页同一个真源。
ThemeMode themeModeFromName(String name) => switch (name) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String themeModeToName(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      themeModeFromName(ref.watch(appSettingsProvider).themeMode);

  Future<void> setMode(ThemeMode mode) => ref
      .read(appSettingsProvider.notifier)
      .patch(themeMode: themeModeToName(mode));
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
