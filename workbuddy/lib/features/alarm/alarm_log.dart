import 'package:flutter/foundation.dart';

/// 闹钟持久化相关日志（T10 验收证据 #5 依赖它）。
///
/// 统一用 `[T10][alarm-persist]` 前缀，便于在 `adb logcat` 里精确过滤：
///   adb -s emulator-5554 logcat -d | findstr "alarm-persist"
const String alarmPersistTag = '[T10][alarm-persist]';

void alarmLog(String message) {
  debugPrint('$alarmPersistTag $message');
}

/// T10.5 原生闹钟层相关日志。
///
/// 与 Kotlin 侧 `alarmLog()` 使用**同一前缀** `[T10.5][alarm-native]`，
/// 因此评审方一条命令就能同时看到 Dart 与原生两侧的证据：
///   adb -s emulator-5554 logcat -d | findstr "alarm-native"
const String alarmNativeTag = '[T10.5][alarm-native]';

void alarmNativeLog(String message) {
  debugPrint('$alarmNativeTag $message');
}

/// T11 开机重建相关日志。
///
/// 与 Kotlin 侧 `alarmLogBoot()` 同前缀 `[T11][alarm-native]`，末尾用 `[dart]` / `[boot]`
/// 区分是哪一侧打的（Dart 启动清理 vs 原生开机重建）。两者都能被
/// `logcat -d | grep -a alarm-native` 一次抓到。
const String alarmBootTag = '[T11][alarm-native][dart]';

void alarmBootLog(String message) {
  debugPrint('$alarmBootTag $message');
}
