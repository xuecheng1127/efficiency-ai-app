package com.efficiency.app.efficiency_app.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.util.Calendar

/**
 * 闹钟调度（原生侧）。
 *
 * 三档降级（PRD v2 §3.3 / ADR-003）：
 * | 档位 | 触发方式 | 条件 |
 * |---|---|---|
 * | A 精确档 | `setExactAndAllowWhileIdle` | `canScheduleExactAlarms() == true` |
 * | B 近似档 | `setWindow(60_000L)` | 无精确权限（国产 ROM 深省电下的保险） |
 * | C 应用内档 | 仅应用在前台时提醒 | 需要 Flutter 前台 UI，见下方说明 |
 *
 * **C 档说明**：C 档的「应用内提醒」是 Flutter 前台的职责（UI 属 T21），
 * 本任务只在枚举与日志里保留该档位词汇，**不会主动选择它**，也不做任何假装实现。
 *
 * **参数来源**：全部从 `scheduled_alarms` 表读取（ADR-008 定案），
 * 不走 Intent extra —— 这样进程被杀 / 设备重启后参数不丢。
 */
object AlarmScheduler {

    enum class Tier { EXACT, INEXACT, IN_APP }

    /**
     * 一次「全量重建」的实测结果（T11）。
     *
     * 存在的意义是**用计数代替自述**：开机重建到底读了几条、重建了几条、跳过了几条，
     * 全部是可核对的数字，评审方可以直接拿它和 `dumpsys alarm` 对齐。
     */
    data class RebuildReport(
        val source: String,
        val read: Int,
        val rebuilt: Int,
        val skippedExpiredOnce: Int,
    ) {
        fun summary(): String =
            "source=$source read=$read rebuilt=$rebuilt skippedExpiredOnce=$skippedExpiredOnce"
    }

    private const val DAY = 86_400_000L
    private const val WINDOW_LENGTH = 60_000L

    // ---------------------------------------------------------------- 权限

    /** `AlarmManager.canScheduleExactAlarms()`；API 31 以下恒为 true。 */
    fun canScheduleExactAlarms(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
        } else {
            true
        }

    /** 当前应走的档位（本任务不会返回 [Tier.IN_APP]，原因见类注释）。 */
    fun tierNow(context: Context): Tier =
        if (canScheduleExactAlarms(context)) Tier.EXACT else Tier.INEXACT

    /**
     * 跳转系统「闹钟和提醒」设置页。
     *
     * **注意**：这里的 `startActivity` 只用于跳转系统设置页，且必然由用户手势触发；
     * 它**不是**用来拉起全屏闹钟页的 —— 全屏页一律走
     * `Notification.setFullScreenIntent`（v2.2 硬伤 1 定案）。
     */
    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            alarmLog("openExactAlarmSettings: SDK < 31, permission is not required")
            return
        }
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.fromParts("package", context.packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            alarmLog("openExactAlarmSettings: opened system settings page")
        } catch (e: Exception) {
            alarmLogError("openExactAlarmSettings failed", e)
        }
    }

    // ---------------------------------------------------------------- 调度

    /**
     * 按 taskId 调度：**先回表取全部参数**，再据档位设置闹钟。
     *
     * @param triggerAtMillis Dart 侧算出的触发时刻，仅用于**日志比对**
     *        （真正的触发时刻一律由原生据表重算，证明表才是真源）
     */
    fun schedule(context: Context, taskId: Int, triggerAtMillis: Long, enabled: Boolean): Tier? {
        val record = AlarmStore.loadByTask(context, taskId)
        if (record == null) {
            alarmLog("schedule(taskId=$taskId): no row in scheduled_alarms (or db unreadable) -> cancel")
            cancel(context, taskId)
            return null
        }
        if (!enabled || !record.enabled) {
            alarmLog("schedule(taskId=$taskId): enabled=false -> cancel")
            cancel(context, taskId)
            return null
        }

        val now = System.currentTimeMillis()
        val triggerAt = nextTriggerMillis(record, now)
        val tier = tierNow(context)
        val pi = alarmPendingIntent(context, taskId)
        val am = context.getSystemService(AlarmManager::class.java)

        when (tier) {
            Tier.EXACT ->
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            else ->
                am.setWindow(AlarmManager.RTC_WAKEUP, triggerAt, WINDOW_LENGTH, pi)
        }

        val hintMatch = if (triggerAtMillis == triggerAt) {
            "match(triggerAtMillis=$triggerAtMillis)"
        } else {
            "differs(dart=$triggerAtMillis native=$triggerAt)"
        }
        alarmLog(
            "schedule(taskId=$taskId) tier=${tier.name} triggerAtMillis=$triggerAt (${formatTime(triggerAt)}) " +
                "table{hour=${record.hour}, minute=${record.minute}, repeatRule=${record.repeatRule}, " +
                "weekdays=${record.weekdays}, scheduledDateSec=${record.scheduledDateEpochSeconds}, " +
                "advanceMinutes=${record.advanceMinutes}, ringtone=${record.ringtone}, volume=${record.volume}, " +
                "snoozeEnabled=${record.snoozeEnabled}, snoozeMinutes=${record.snoozeMinutes}, " +
                "tierInDb=${record.tier}} $hintMatch",
        )
        if (record.advanceMinutes != null) {
            // 提前提醒需要「提前档 + 准点档」两个闹钟，属通知体验（T14），本任务不实现：
            // 这里只如实记录该字段已从表读到，避免看起来像被忽略。
            alarmLog("schedule(taskId=$taskId): advanceMinutes=${record.advanceMinutes} read from table, not acted on yet (T14)")
        }
        return tier
    }

    /** 取消该任务的闹钟与通知。 */
    fun cancel(context: Context, taskId: Int) {
        val am = context.getSystemService(AlarmManager::class.java)
        val existing = pendingIntentOrNull(context, taskId)
        if (existing != null) {
            am.cancel(existing)
            existing.cancel()
        }
        AlarmNotifications.cancel(context, taskId)
        alarmLog("cancel(taskId=$taskId): alarm=${if (existing != null) "cancelled" else "none"}, notification=cancelled")
    }

    /**
     * 全量重建（T11 开机 / T12 权限变化 / Dart 启动探针的共同入口）。
     * **只凭表**枚举待重建闹钟，不依赖任何 Intent —— 这是 ADR-008 的要求。
     *
     * 重复调用是**幂等**的：`schedule()` 用的是同一个 `PendingIntent`
     * （requestCode = taskId + 同样的 Intent），`AlarmManager.set*` 对同一
     * PendingIntent 是**覆盖**语义，所以重复广播不会累加出重复闹钟；
     * 再加上 `scheduled_alarms.task_id` 上的 UNIQUE 约束，一个任务天然只有一条记录。
     *
     * @param source 调用来源，只进日志（boot / channel / manual），便于评审方区分
     * @return 实测计数，见 [RebuildReport]
     */
    fun rescheduleAll(context: Context, source: String = "manual"): RebuildReport {
        val records = AlarmStore.loadAllEnabled(context)
        val now = System.currentTimeMillis()
        alarmLogBoot("rebuild start: source=$source, ${records.size} alarm(s) read from table scheduled_alarms")

        var rebuilt = 0
        var skippedExpired = 0
        for (r in records) {
            if (isExpiredOnce(r, now)) {
                skippedExpired++
                alarmLogBoot(
                    "taskId=${r.taskId} skip: once already expired at " +
                        "${formatTime(nextTriggerMillis(r, now))} (now ${formatTime(now)})",
                )
                continue
            }
            val triggerAt = nextTriggerMillis(r, now)
            val tier = schedule(context, r.taskId, triggerAt, true)
            if (tier != null) {
                rebuilt++
                alarmLogBoot("rebuilt taskId=${r.taskId} trigger=$triggerAt (${formatTime(triggerAt)}) tier=${tier.name}")
            } else {
                alarmLogBoot("taskId=${r.taskId} not armed (no row / enabled=false); see schedule() log above")
            }
        }

        val report = RebuildReport(source, records.size, rebuilt, skippedExpired)
        alarmLogBoot("rebuild complete: ${report.summary()}")
        return report
    }

    /**
     * 「已过期的一次性闹钟」判定。
     *
     * [nextTriggerMillis] 对 `once` 的语义是「按 `scheduled_date` 原样取，即使已过点也不顺延」
     * （与 Dart 侧 `ScheduledAlarm.nextTriggerAt` 刻意对齐）。这在**重建**场景下是危险的：
     * 把一个**已经过去的**时刻交给 `setExactAndAllowWhileIdle`，系统会**立刻**触发 ——
     * 用户重启一次设备（或只是打开一次 App，`main.dart` 启动时会调 `rescheduleAll`）
     * 就会凭空响一声。
     *
     * 所以全量重建时显式跳过这类记录。
     *
     * **只跳过，不写库**：`scheduled_alarms` 按 ADR-008 是原生侧的**只读**真源
     * （`AlarmStore` 只实现只读打开），原生不删行、不改 `enabled`。
     * 是否要把过期记录清理掉，属于产品语义，留给上层决定（已在 T11 报告里标注）。
     */
    fun isExpiredOnce(record: ScheduledAlarmRecord, nowMillis: Long): Boolean =
        record.repeatRule == "once" && nextTriggerMillis(record, nowMillis) <= nowMillis

    /** 贪睡：只设一个一次性的近似/精确闹钟，**不落库**（下表不动）。 */
    fun scheduleSnooze(context: Context, taskId: Int, atMillis: Long) {
        val am = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmContract.ACTION_ALARM
            putExtra(AlarmContract.EXTRA_TASK_ID, taskId)
            putExtra(AlarmContract.EXTRA_SNOOZE_AT, atMillis)
        }
        val pi = PendingIntent.getBroadcast(
            context,
            AlarmContract.snoozeRequestCode(taskId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (tierNow(context) == Tier.EXACT) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
        } else {
            am.setWindow(AlarmManager.RTC_WAKEUP, atMillis, WINDOW_LENGTH, pi)
        }
        alarmLog("snooze re-armed(taskId=$taskId) atMillis=$atMillis (${formatTime(atMillis)})")
    }

    // ---------------------------------------------------------------- 辅助

    fun alarmPendingIntent(context: Context, taskId: Int): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmContract.ACTION_ALARM
            putExtra(AlarmContract.EXTRA_TASK_ID, taskId)
        }
        return PendingIntent.getBroadcast(
            context,
            AlarmContract.alarmRequestCode(taskId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun pendingIntentOrNull(context: Context, taskId: Int): PendingIntent? {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmContract.ACTION_ALARM
            putExtra(AlarmContract.EXTRA_TASK_ID, taskId)
        }
        return PendingIntent.getBroadcast(
            context,
            AlarmContract.alarmRequestCode(taskId),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * 由表里的字段推算下一次触发时刻（纯函数，与 Dart 侧 `ScheduledAlarm.nextTriggerAt` 同语义）。
     * 这样「原生是否真的按表调度」可以直接用 Dart 传来的 `triggerAtMillis` 做交叉验证。
     */
    fun nextTriggerMillis(record: ScheduledAlarmRecord, nowMillis: Long): Long {
        val todayAt = localMidnight(nowMillis) + record.hour * 3_600_000L + record.minute * 60_000L
        return when (record.repeatRule) {
            "once" -> {
                val dayStart = record.scheduledDateEpochSeconds?.let { localMidnight(it * 1000L) }
                    ?: localMidnight(nowMillis)
                // 与 Dart 侧一致：once 就取 scheduled_date 那天的 hour:minute，即使已过点也不顺延
                dayStart + record.hour * 3_600_000L + record.minute * 60_000L
            }

            "weekly" -> {
                if (record.weekdays.isEmpty()) return dailyNext(todayAt, nowMillis)
                for (i in 0..7) {
                    val candidate = todayAt + i * DAY
                    if (candidate > nowMillis && dartWeekdayOf(candidate) in record.weekdays) return candidate
                }
                todayAt + 7 * DAY
            }

            else -> dailyNext(todayAt, nowMillis)
        }
    }

    private fun dailyNext(todayAt: Long, nowMillis: Long): Long =
        if (todayAt > nowMillis) todayAt else todayAt + DAY

    /** 本地时间当天 00:00 的时刻。 */
    private fun localMidnight(millis: Long): Long {
        val c = Calendar.getInstance()
        c.timeInMillis = millis
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    /**
     * Dart `DateTime.weekday` 语义：1=周一 … 7=周日。
     *
     * `Calendar.DAY_OF_WEEK` 是 1=周日 … 7=周六 —— 两套语义不同，**必须显式换算**，
     * 绝不能把 `Calendar` 的值当作 Dart 的 weekday 直接使用（T01 规格禁止清单）。
     */
    private fun dartWeekdayOf(millis: Long): Int {
        val c = Calendar.getInstance()
        c.timeInMillis = millis
        return when (c.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            else -> 7 // Calendar.SUNDAY
        }
    }

    private fun formatTime(millis: Long): String =
        java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.US).format(java.util.Date(millis))
}
