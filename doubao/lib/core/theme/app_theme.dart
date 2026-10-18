import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 全局主题工厂（Material 3）
/// 支持 浅色 / 深色 / 跟随系统 三种模式，由设置页全局切换。
abstract final class AppTheme {
  /// 构建浅色主题
  static ThemeData light() => _build(Brightness.light);

  /// 构建深色主题
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,

      // ---- 全局卡片圆角统一 12dp ----
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.cardRadius),
        ),
        color: scheme.surface,
        margin: EdgeInsets.zero,
      ),

      // ---- 页面过渡动画：200-300ms easeOutCubic ----
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ---- 水波纹点击反馈 ----
      splashFactory: InkRipple.splashFactory,

      // ---- 通用排版 ----
      textTheme: Typography.material2021().black.apply(
            bodyColor: isDark ? AppColors.textDark : AppColors.textLight,
            displayColor: isDark ? AppColors.textDark : AppColors.textLight,
          ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textDark : AppColors.textLight,
        ),
      ),

      // ---- 输入框 ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.cardRadius),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // ---- 列表回弹效果（iOS 风格回弹，安卓亦可用） ----
      // BouncingScrollPhysics 已在具体列表组件中使用
    );
  }
}
