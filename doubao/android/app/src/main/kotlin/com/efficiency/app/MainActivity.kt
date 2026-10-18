package com.efficiency.app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.efficiency.app.alarm.AlarmScheduler

/**
 * 应用主 Activity
 *
 * V1.2 新增：注册「alarm_channel」MethodChannel，封装原生闹钟能力
 * （统一通过 MethodChannel 对接安卓原生，需求文档约束）：
 * - scheduleTaskAlarm / cancelTaskAlarm / cancelAllAlarms
 * - canScheduleExactAlarms / requestExactAlarmPermission
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.efficiency.app/alarm"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // T19：注册原生 WorkManager 周期扫描兜底（幂等）
        com.efficiency.app.alarm.AlarmScanWorker.enqueue(this)
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                handleAlarmCall(call, result)
            }
    }

    private fun handleAlarmCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // 调度任务闹钟（触发时刻已由 Dart 侧按重复规则计算）
            "scheduleTaskAlarm" -> {
                try {
                    val args = call.arguments as? Map<*, *> ?: throw IllegalArgumentException("args required")
                    val triggerAt = (args["triggerAtMillis"] as? Number)?.toLong() ?: throw IllegalArgumentException("triggerAtMillis required")
                    AlarmScheduler.scheduleTaskAlarm(
                        context = this,
                        taskId = (args["taskId"] as? Number)?.toInt() ?: 0,
                        title = (args["title"] as? String) ?: "任务提醒",
                        triggerAtMillis = triggerAt,
                        hourOfDay = (args["hourOfDay"] as? Number)?.toInt() ?: 0,
                        minute = (args["minute"] as? Number)?.toInt() ?: 0,
                        repeatRule = (args["repeatRule"] as? Number)?.toInt() ?: AlarmScheduler.REPEAT_ONCE,
                        weekdays = ((args["weekdays"] as? List<*>) ?: emptyList<Any>())
                            .mapNotNull { (it as? Number)?.toInt() },
                        scheduledDateMillis = (args["scheduledDateMillis"] as? Number)?.toLong(),
                        advanceMinutes = (args["advanceMinutes"] as? Number)?.toInt() ?: 0,
                        ringtone = (args["ringtone"] as? String) ?: "晨曦",
                        volume = (args["volume"] as? Number)?.toInt() ?: 80,
                        snoozeEnabled = (args["snoozeEnabled"] as? Boolean) ?: true,
                        snoozeMinutes = (args["snoozeMinutes"] as? Number)?.toInt() ?: 5,
                    )
                    result.success(true)
                } catch (e: Exception) {
                    result.error("schedule_failed", e.message, null)
                }
            }
            // 取消任务闹钟
            "cancelTaskAlarm" -> {
                val taskId = (call.arguments as? Number)?.toInt() ?: 0
                AlarmScheduler.cancelTaskAlarm(this, taskId)
                result.success(true)
            }
            // 是否拥有精确闹钟权限
            "canScheduleExactAlarms" -> {
                result.success(AlarmScheduler.canScheduleExactAlarms(this))
            }
            // 引导用户开启精确闹钟权限（Android 12+）
            "requestExactAlarmPermission" -> {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    intent.data = android.net.Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("permission_intent_failed", e.message, null)
                }
            }
            // T12：前台兜底——重排全部已存闹钟（权限档位变化后调用）
            "rescheduleAll" -> {
                try {
                    com.efficiency.app.alarm.BootReceiver.rebuildAlarms(this)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("reschedule_failed", e.message, null)
                }
            }
            // T19：WorkManager 周期扫描兜底
            "rescanMissedAlarms" -> {
                try {
                    val count = com.efficiency.app.alarm.AlarmScheduler.rescanMissedAlarms(this)
                    result.success(count)
                } catch (e: Exception) {
                    result.error("rescan_failed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
