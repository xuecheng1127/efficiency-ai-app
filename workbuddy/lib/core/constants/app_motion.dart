import 'package:flutter/animation.dart';

/// 全局动效常量（见需求文档「全局交互规范 · 动效统一」）
abstract final class AppMotion {
  /// 过渡动画时长统一 200-300ms
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 300);

  /// 全局缓动曲线 easeOutCubic
  static const Curve easeOutCubic = Cubic(0.215, 0.61, 0.355, 1.0);
}
