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
