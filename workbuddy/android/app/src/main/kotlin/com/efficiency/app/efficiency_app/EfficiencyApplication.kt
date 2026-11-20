package com.efficiency.app.efficiency_app

import android.app.Application
import android.util.Log
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * ============================================================================
 * 应用级入口：给「后台任务引擎」补上插件注册（R4 的关键一步）
 * ============================================================================
 *
 * 背景（实测，不猜）：
 * `flutter_foreground_task` 8.17 起，服务里的 `ForegroundTask` 会 `FlutterEngine(context)`
 * 新建一个**独立的 Flutter 引擎**来跑 `TaskHandler`。这个引擎默认**不注册任何插件**，
 * 于是任务里所有走 MethodChannel 的能力全部失效。第一次装 v1.6 的日志是：
 *
 *   [geofence] prefs unavailable: PlatformException(channel-error,
 *     Unable to establish connection on channel:
 *     "dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.getAll")
 *
 * 症状很隐蔽：位置、通知、prefs 全都静默失败，看起来像「定位拿不到」。
 *
 * 插件本身留了官方口子 `FlutterForegroundTaskPlugin.addTaskLifecycleListener`，
 * 注释写得很清楚：「This is called before onTaskStart. Initialize the service
 * you want to use in the task. (like PlatformChannel initialization)」。
 * 这里就在 `onEngineCreate` 里把 **GeneratedPluginRegistrant** 挂上去 ——
 * 与主引擎走同一份注册表，所以 prefs / geolocator / local_notifications 一次性都通。
 *
 * 为什么放在 Application 而不是 MainActivity：
 * `autoRunOnBoot` 为真时，开机后是**服务**把进程拉起来的，Activity 根本不会创建。
 * 放在 Activity 里等于「只有用户手动打开过 App 之后后台监测才正常」。
 */
class EfficiencyApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        FlutterForegroundTaskPlugin.addTaskLifecycleListener(
            object : FlutterForegroundTaskLifecycleListener {
                override fun onEngineCreate(flutterEngine: FlutterEngine?) {
                    if (flutterEngine == null) return
                    try {
                        GeneratedPluginRegistrant.registerWith(flutterEngine)
                        Log.i(TAG, "background engine plugins registered")
                    } catch (e: Exception) {
                        // 注册失败不让进程崩：前台功能仍然可用，
                        // Dart 侧会把「读不到状态」当成这一拍跳过，不会自杀。
                        Log.e(TAG, "background engine plugin registration failed", e)
                    }
                }

                override fun onTaskStart(starter: FlutterForegroundTaskStarter) {}

                override fun onTaskRepeatEvent() {}

                override fun onTaskDestroy() {}

                override fun onEngineWillDestroy() {}
            },
        )
    }

    private companion object {
        const val TAG = "EfficiencyApp"
    }
}
