package com.efficiency.app.alarm

import android.content.Context
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

/**
 * T19：纯原生 WorkManager 周期扫描兜底
 *
 * 为什么不用 Dart MethodChannel：
 * - WorkManager 的 worker 跑在独立后台 FlutterEngine
 * - 那个 engine 没有 MainActivity 注册的 channel
 * - invokeMethod 抛 MissingPluginException 被吞
 *
 * 所以直接在原生层调 AlarmScheduler.rescanMissedAlarms
 */
class AlarmScanWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        return try {
            val n = AlarmScheduler.rescanMissedAlarms(applicationContext)
            Log.i("AlarmRescan", "native worker done compensated=$n")
            Result.success()
        } catch (e: Exception) {
            Log.e("AlarmRescan", "native worker failed", e)
            Result.retry()
        }
    }

    companion object {
        fun enqueue(context: Context) {
            val req = PeriodicWorkRequestBuilder<AlarmScanWorker>(15, TimeUnit.MINUTES).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "alarm_rescan_native", ExistingPeriodicWorkPolicy.KEEP, req)
        }
    }
}
