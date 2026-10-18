import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// Material 3 主题：支持浅色 / 深色，全局一键切换
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // 以主题蓝为种子色生成完整配色体系
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.active,
      brightness: brightness,
    );

    // 种子色在浅色下把层级方向算反了：页面 #FAF8FF 比卡片 #F4F3FA 更亮，卡片像「凹槽」。
    // 只覆盖这两个层级的色值：页面更暗、卡片更亮。深色方向本来就是对的，原样保留。
    final scheme = brightness == Brightness.light
        ? base.copyWith(
            surface: AppColors.lightSurface,
            surfaceContainerLow: AppColors.lightCard,
          )
        : base;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // 卡片统一 12dp 圆角
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      // 全局水平内边距 16dp
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // 输入框圆角统一
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
      ),
      // FAB 与按钮主题
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppDimens.minTapSize, AppDimens.minTapSize),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          ),
        ),
      ),
    );
  }
}
