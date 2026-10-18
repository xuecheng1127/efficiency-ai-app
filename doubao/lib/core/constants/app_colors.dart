import 'package:flutter/material.dart';

/// 全局状态色规范（全 APP 复用，Material 3）
/// 需求文档「全局视觉规范-状态色统一」：
///   未完成/默认 → 中性灰 #9CA3AF
///   进行中/激活 → 主题蓝 #2563EB
///   已完成/成功 → 柔和绿 #10B981
///   警告/盈余   → 暖橙 #F59E0B
///   错误/危险   → 柔红 #EF4444
abstract final class AppColors {
  // ---- 状态色 ----
  static const Color neutral = Color(0xFF9CA3AF); // 未完成/默认
  static const Color primary = Color(0xFF2563EB); // 进行中/激活（主题蓝）
  static const Color success = Color(0xFF10B981); // 已完成/成功
  static const Color warning = Color(0xFFF59E0B); // 警告/盈余
  static const Color danger = Color(0xFFEF4444); // 错误/危险

  // ---- 基础色 ----
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF1F2937);
  static const Color textDark = Color(0xFFF1F5F9);

  // ---- 通用常量 ----
  static const double pagePadding = 16.0; // 全局水平内边距
  static const double cardRadius = 12.0; // 卡片圆角
  static const double minTouchTarget = 44.0; // 最小可点击区域 44×44dp
}

/// 动效规范
abstract final class AppMotion {
  /// 全局过渡动画时长 200-300ms，取中值
  static const Duration pageTransition = Duration(milliseconds: 260);

  /// 统一缓动曲线 easeOutCubic
  static const Curve easeOutCubic = Curves.easeOutCubic;
}
