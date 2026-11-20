# ============================================================================
# R8 / ProGuard 规则（release 构建）
# ============================================================================
# 为什么需要这个文件：
#   加完 image_picker 之后，release APK 一启动就崩：
#     java.lang.RuntimeException: Failed to create an instance of class
#       androidx.work.impl.WorkDatabase.canonicalName
#     at androidx.startup.InitializationProvider.onCreate
#   原因：T19 引入的 WorkManager 用 Room 生成 `WorkDatabase_Impl`，它在运行时
#   按**类名字符串**反射创建；R8 把类名混淆掉后反射找不到类，初始化直接抛异常。
#   这是 WorkManager + R8 的经典问题（AAR 自带的 consumer rules 在部分 AGP
#   组合下不生效），显式 keep 是最稳的修法。
#
# 注意：Flutter 的 release 默认不开 shrink，但 AGP 仍会跑 R8 并混淆类名，
# 所以这些规则是必需的，去掉就会复发。
# ============================================================================

# WorkManager：反射创建 Room 数据库 + Worker 子类按类名实例化
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * implements androidx.work.WorkerFactory { *; }

# Room：生成的 *_Impl 由 Room.databaseBuilder 按类名反射加载
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.room.RoomDatabase { *; }

# androidx.startup：InitializationProvider 按类名反射实例化 Initializer
-keep class androidx.startup.** { *; }

# 本项目原生闹钟层（T10 / T11 / T19）由 Dart 侧通过 MethodChannel 调用，
# 方法名不经过反射，但广播接收器（BootReceiver 等）是按 Manifest 类名实例化的。
-keep class com.efficiency.app.efficiency_app.** { *; }

# R8 对缺失的可选依赖只警告，不阻断构建
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# 桌面小组件（R2）：TodayTasksWidgetProvider 继承插件的 HomeWidgetProvider，
# provider 类名由 Manifest 指定（已由上一条 keep 覆盖）；这里再显式保留插件包，
# 因为 HomeWidgetScheduler 会按**类名字符串**解析 AppWidgetProvider（广播重排刷新）。
-keep class es.antonborri.home_widget.** { *; }

# ============================================================================
# R4B：插件通道（pigeon / MethodChannel）的类必须保留
# ============================================================================
# 背景：v1.6 的 release 包在真机/模拟器上报
#   PlatformException(channel-error, Unable to establish connection on channel:
#     "dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.getAll")
# 说明「Dart 侧发出了消息，原生侧没有 handler」。R8 把 pigeon 生成的
# `*Api` / `*PigeonApi` 类当无引用代码裁掉后，插件 `onAttachedToEngine` 里
# 注册 handler 的那一行就没了 —— 编译期不报错，运行期静默失败。
# 这些 keep 对体积影响可忽略（几个类），但能保证「插件注册」这件事不被优化掉。
-keep class dev.flutter.pigeon.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class es.antonborri.home_widget.** { *; }
-keep class com.pravera.flutter_foreground_task.** { *; }
-keep class com.baseflow.geolocator.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# pigeon 的生成类里有大量 `@Keep` 之外的反序列化路径，缺类只在运行期炸
-dontwarn dev.flutter.pigeon.**
