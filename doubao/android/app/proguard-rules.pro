# Flutter 默认保留
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Drift / 生成代码
-keep class com.efficiency.app.** { *; }
-keepclassmembers class com.efficiency.app.** { *; }

# 位置/前台服务插件
-keep class com.lyokone.location.** { *; }
-keep class com.dexterous.** { *; }

# home_widget 桌面小组件插件（Provider 由系统按类名反射实例化）
-keep class es.antonborri.home_widget.** { *; }

# Play Core 分包相关类（本工程不使用动态分发，R8 忽略缺失）
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
