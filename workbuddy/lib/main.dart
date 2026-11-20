import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/material.dart';

import 'app/bootstrap_app.dart';
import 'core/diagnostics/startup_trace.dart';

/// 入口只做一件事：把「启动」交给 [BootstrapApp]。
///
/// 为什么不再在这里 `await` 一串初始化：
/// 那样任何一步失败（最典型的是数据库文件损坏）都会让 `runApp` 永远不执行，
/// 用户只会看到一个停在 Flutter logo 的白屏。现在失败会被接住，
/// 变成一张带「重新尝试 / 备份并重建」的错误页（见 HARDENING A4）。
void main() {
  // R5：t0 = Dart 入口。`am start -W TotalTime` 减去这里累计的 total，
  // 就是「进程 fork + 引擎初始化 + isolate 启动」这段 Dart 看不到的时间。
  StartupTrace.mark('dart.main.entry');
  WidgetsFlutterBinding.ensureInitialized();
  StartupTrace.mark('binding.ready');
  // R4B：`DartPluginRegistrant` 必须显式登记。缺了它，插件只有「原生侧注册了
  // handler、Dart 侧没登记实现」—— 任何插件调用都会变成
  // `PlatformException(channel-error)`。这一行同时也是后台 isolate 的前提
  // （那边在 TaskHandler.onStart 里再登记一次，见 location_task_handler.dart）。
  DartPluginRegistrant.ensureInitialized();
  runApp(const BootstrapApp());
  StartupTrace.mark('runApp.returned');
}
