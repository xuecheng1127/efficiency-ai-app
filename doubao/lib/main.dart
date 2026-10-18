import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/task_timer_service.dart';
import 'features/toolbox/data/location_background_worker.dart';

/// 效率助手 V1.2 应用入口（T01：数据层已切换为 Drift）
///
/// 技术栈约束（需求文档）：
/// - Flutter 3.x + Dart 3.x，全原生组件渲染（无 WebView 套壳）；
/// - Riverpod 2.x 状态管理，统一 AsyncValue 异步状态；
/// - Drift (SQLite) 本地数据库，双层模型 task_templates/task_instances，
///   freezed + json_serializable 状态/实体类；
/// - 最低兼容安卓 10（API 29）。
///
/// 计时器前台服务（V1.1）：
/// - initCommunicationPort：TaskHandler 后台 isolate 与主 isolate 的通信端口，
///   必须在 runApp 之前调用；
/// - TaskTimerService.init：配置前台服务通知渠道/心跳，异步初始化不阻塞启动。
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化前台服务通信端口（TaskHandler ↔ 主 isolate）
  FlutterForegroundTask.initCommunicationPort();
  // 异步初始化前台服务配置（通知渠道、心跳间隔等）
  unawaited(TaskTimerService.instance.init());
  // WorkManager 后台位置检查
  unawaited(LocationBgWorker.init());

  runApp(const ProviderScope(child: EfficiencyApp()));
}
