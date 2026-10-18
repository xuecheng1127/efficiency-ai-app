import 'package:flutter/material.dart';

/// 全局状态色（全 APP 复用，见需求文档「全局视觉规范 · 状态色统一」）
abstract final class AppColors {
  /// 未完成 / 默认 —— 中性灰
  static const Color todo = Color(0xFF9CA3AF);

  /// 进行中 / 激活 —— 主题蓝
  static const Color active = Color(0xFF2563EB);

  /// 已完成 / 成功 —— 柔和绿
  static const Color success = Color(0xFF10B981);

  /// 警告 / 盈余 —— 暖橙
  static const Color warning = Color(0xFFF59E0B);

  /// 错误 / 危险 —— 柔红
  static const Color danger = Color(0xFFEF4444);

  /// 浅色模式页面底色：比卡片暗，卡片才能「浮」在页面之上
  static const Color lightSurface = Color(0xFFF7F8FA);

  /// 浅色模式卡片底色：纯白，与页面拉开 8/255 的层级差
  static const Color lightCard = Color(0xFFFFFFFF);
}
