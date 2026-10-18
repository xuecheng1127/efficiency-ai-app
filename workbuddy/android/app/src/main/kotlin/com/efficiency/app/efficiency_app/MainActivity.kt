package com.efficiency.app.efficiency_app

import android.os.Bundle
import com.efficiency.app.efficiency_app.alarm.AlarmContract
import com.efficiency.app.efficiency_app.alarm.AlarmScanScheduler
import com.efficiency.app.efficiency_app.alarm.AlarmScheduler
import com.efficiency.app.efficiency_app.alarm.alarmLog
import com.efficiency.app.efficiency_app.alarm.alarmLogError
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 唯一入口 Activity，同时是 `efficiency_app/alarm` 通道的原生端点。
 *
 * 契约**逐字**对应 `lib/core/platform/alarm_channel.dart`（不得改动 Dart 侧）：
 *
 * | method | 参数 | 返回 |
 * |---|---|---|
 * | `canScheduleExactAlarms` | 无 | `bool` |
 * | `requestExactAlarmPermission` | 无 | 无 |
 * | `schedule` | `{taskId, triggerAtMillis, enabled}` | 档位名（仅日志用） |
 * | `cancel` | `{taskId}` | 无 |
 * | `rescheduleAll` | 无 | 重建条数（仅日志用） |
 *
 * 注意 `schedule` 的入参**只有 taskId + 触发时刻**：闹钟的全部参数由原生侧回到
 * `scheduled_alarms` 表读取（ADR-008 定案），不从 Intent extra 传。
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // T19：登记 B 档（无精确权限）漏响兜底的周期扫描。
        // 幂等：KEEP 策略保证不会因为「每次启动都调一次」而重置已有周期。
        // WorkManager 自己持久化周期任务并在设备重启后恢复，所以不需要动 T11 的开机广播。
        AlarmScanScheduler.ensureScheduled(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AlarmContract.CHANNEL)
            .setMethodCallHandler { call, result -> handleAlarmCall(call, result) }
        alarmLog("MethodChannel '${AlarmContract.CHANNEL}' registered")
    }

    private fun handleAlarmCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "canScheduleExactAlarms" -> {
                    val exact = AlarmScheduler.canScheduleExactAlarms(this)
                    alarmLog("channel canScheduleExactAlarms -> $exact")
                    result.success(exact)
                }

                "requestExactAlarmPermission" -> {
                    alarmLog("channel requestExactAlarmPermission -> open system settings")
                    AlarmScheduler.openExactAlarmSettings(this)
                    result.success(null)
                }

                "schedule" -> {
                    val taskId = call.intArg("taskId")
                    val triggerAt = call.longArg("triggerAtMillis")
                    val enabled = call.boolArg("enabled", true)
                    if (taskId == null || triggerAt == null) {
                        alarmLogError("channel schedule: bad args (taskId=$taskId, triggerAtMillis=$triggerAt)")
                        result.error("BAD_ARGS", "taskId and triggerAtMillis are required", null)
                        return
                    }
                    val tier = AlarmScheduler.schedule(this, taskId, triggerAt, enabled)
                    alarmLog("channel schedule(taskId=$taskId) -> tier=${tier?.name ?: "none"}")
                    result.success(tier?.name)
                }

                "cancel" -> {
                    val taskId = call.intArg("taskId")
                    if (taskId == null) {
                        alarmLogError("channel cancel: bad args (taskId=null)")
                        result.error("BAD_ARGS", "taskId is required", null)
                        return
                    }
                    AlarmScheduler.cancel(this, taskId)
                    alarmLog("channel cancel(taskId=$taskId) -> ok")
                    result.success(null)
                }

                "rescheduleAll" -> {
                    // T11 起返回 RebuildReport（含「跳过的过期 once」计数）；
                    // **通道对 Dart 的返回值仍是 int**，Dart 契约未变。
                    val report = AlarmScheduler.rescheduleAll(this, source = "channel")
                    alarmLog("channel rescheduleAll -> ${report.summary()}")
                    result.success(report.rebuilt)
                }

                else -> {
                    alarmLogError("channel: unknown method '${call.method}'")
                    result.notImplemented()
                }
            }
        } catch (e: Throwable) {
            alarmLogError("channel '${call.method}' threw", e)
            result.error("ALARM_CHANNEL_ERROR", e.message ?: e.javaClass.simpleName, null)
        }
    }
}

// Dart 的 int 经标准编解码后可能是 Integer 也可能是 Long（取决于位宽），统一按 Number 取
private fun MethodCall.intArg(key: String): Int? = (argument<Any?>(key) as? Number)?.toInt()

private fun MethodCall.longArg(key: String): Long? = (argument<Any?>(key) as? Number)?.toLong()

private fun MethodCall.boolArg(key: String, fallback: Boolean): Boolean =
    (argument<Any?>(key) as? Boolean) ?: fallback
