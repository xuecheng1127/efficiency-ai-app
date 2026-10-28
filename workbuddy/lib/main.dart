import 'package:flutter/material.dart';

import 'app/bootstrap_app.dart';

/// 入口只做一件事：把「启动」交给 [BootstrapApp]。
///
/// 为什么不再在这里 `await` 一串初始化：
/// 那样任何一步失败（最典型的是数据库文件损坏）都会让 `runApp` 永远不执行，
/// 用户只会看到一个停在 Flutter logo 的白屏。现在失败会被接住，
/// 变成一张带「重新尝试 / 备份并重建」的错误页（见 HARDENING A4）。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}
