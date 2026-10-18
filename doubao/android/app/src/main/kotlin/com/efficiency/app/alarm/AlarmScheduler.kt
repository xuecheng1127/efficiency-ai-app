package com.efficiency.app.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * 精确闹钟调度器（模块1 闹钟提醒系统，V1.2）
 *
 * 需求约束：
 * - 调用原生 AlarmManager.setExactAndAllowWhileIdle，
 *   降低被系统电池优化杀死的概率（Doze 模式下仍可触发）。
 * - 提前 15/30 分钟提醒：触发时刻 = 任务闹钟时间 - 提前量。
 * - 重复任务自持：响铃后由 AlarmReceiver 依据重复规则自动排下一次，
 *   App 不在前台甚至进程被杀也能按日/周响铃（但设备重启后需 BootReceiver 重建）。
 *
 * 请求码设计（避免冲突）：
 * - 正常闹钟：taskId * 10
 * - 贪睡闹钟：taskId * 10 + 1
 * 取消时以相同 requestCode + Intent 组件匹配，可直接作废旧 PendingIntent。
 *
 * 降级策略（权限拒绝时自动降级，不崩溃）：
 * - Android 12（API 31）引入 SCHEDULE_EXACT_ALARM 且默认授予；
 *   Android 14（API 34）起默认拒绝。canScheduleExactAlarms() == false 时
 *   降级为 setWindow（近精确，≤1 分钟窗口）。
 */
object AlarmScheduler {

    const val REPEAT_ONCE = 0
    const val REPEAT_DAILY = 1
    const val REPEAT_WEEKLY = 2

    /** 正常闹钟请求码 */
    private fun normalRequestCode(taskId: Int): Int = taskId * 10

    /** 贪睡闹钟请求码 */
    private fun snoozeRequestCode(taskId: Int): Int = taskId * 10 + 1

    /**
     * 计算下一次触发时刻（epoch millis）。
     *
     * @param nowMillis 当前时间
     * @param hourOfDay 任务闹钟小时（0-23）
     * @param minute 任务闹钟分钟（0-59）
     * @param repeatRule REPEAT_ONCE / REPEAT_DAILY / REPEAT_WEEKLY
     * @param weekdays Dart 语义的固定日列表（1=周一 ... 7=周日）
     * @param scheduledDateMillis 单次任务的计划日期（epoch millis，可为 null）
     * @param advanceMinutes 提前量（0/15/30），触发时刻 = 闹钟时刻 - 提前量
     * @return 下一次触发时刻；无未来时刻返回 null（单次任务已过期）
     */
    fun nextTriggerMillis(
        nowMillis: Long,
        hourOfDay: Int,
        minute: Int,
        repeatRule: Int,
        weekdays: List<Int>,
        scheduledDateMillis: Long?,
        advanceMinutes: Int,
    ): Long? {
        val now = Calendar.getInstance().apply { timeInMillis = nowMillis }

        // 基于某个日期构造"闹钟时刻 - 提前量"，仅当结果在未来时返回
        fun candidate(base: Calendar): Long? {
            val c = base.clone() as Calendar
            c.set(Calendar.HOUR_OF_DAY, hourOfDay)
            c.set(Calendar.MINUTE, minute)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            c.add(Calendar.MINUTE, -advanceMinutes)
            return if (c.timeInMillis > nowMillis) c.timeInMillis else null
        }

        return when (repeatRule) {
            REPEAT_ONCE -> {
                // 单次：只在计划日期当天响，过期不再排
                val scheduled = scheduledDateMillis ?: return null
                val day = Calendar.getInstance().apply { timeInMillis = scheduled }
                candidate(day)
            }
            REPEAT_DAILY -> {
                // 每日：今天未到则今天，已到则明天
                candidate(now) ?: candidate(
                    (now.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
                )
            }
            else -> {
                // 每周：从今天起向后找第一个匹配的固定日
                var base = now.clone() as Calendar
                for (i in 0 until 7) {
                    // Calendar.DAY_OF_WEEK：1=周日 ... 7=周六
                    val calWeekday = base.get(Calendar.DAY_OF_WEEK)
                    // 转换为 Dart 语义：1=周一 ... 7=周日
                    val dartWeekday = if (calWeekday == Calendar.SUNDAY) 7 else calWeekday - 1
                    if (weekdays.contains(dartWeekday)) {
                        val t = candidate(base)
                        if (t != null) return t
                    }
                    base.add(Calendar.DAY_OF_YEAR, 1)
                }
                null
            }
        }
    }

    /**
     * 调度任务闹钟（setExactAndAllowWhileIdle；无精确权限时降级 setWindow）。
     *
     * @param taskId 任务主键
     * @param title 任务标题（全屏页展示）
     * @param triggerAtMillis 触发时刻（由 [nextTriggerMillis] 计算）
     * @param repeatRule 重复规则
     * @param weekdays 固定日列表
     * @param scheduledDateMillis 单次计划日期
     * @param ringtone 铃音标识（Dart 侧全局设置）
     * @param volume 铃声音量 0-100
     * @param snoozeEnabled 贪睡开关
     * @param snoozeMinutes 贪睡间隔（分钟）
     */
    fun scheduleTaskAlarm(
        context: Context,
        taskId: Int,
        title: String,
        triggerAtMillis: Long,
        hourOfDay: Int,
        minute: Int,
        repeatRule: Int,
        weekdays: List<Int>,
        scheduledDateMillis: Long?,
        advanceMinutes: Int,
        ringtone: String,
        volume: Int,
        snoozeEnabled: Boolean,
        snoozeMinutes: Int,
    ) {
        // 先作废旧闹钟（正常 + 贪睡），避免重复调度
        cancelTaskAlarm(context, taskId)

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = buildPendingIntent(
            context, taskId, title,
            hourOfDay, minute, repeatRule, weekdays, scheduledDateMillis,
            advanceMinutes, ringtone, volume, snoozeEnabled, snoozeMinutes,
            isSnooze = false, snoozeCount = 0,
            requestCode = normalRequestCode(taskId),
        )

        // 需求硬约束：精确闹钟防杀；无权限时降级，绝不崩溃
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
            am.setWindow(AlarmManager.RTC_WAKEUP, triggerAtMillis, 60_000L, pi)
        } else {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }

    /**
     * 调度贪睡闹钟：当前时刻 + snoozeMinutes 后再次响铃。
     * 贪睡最多 3 次（snoozeCount >= 3 时上层不再提供入口）。
     */
    fun scheduleSnoozeAlarm(
        context: Context,
        taskId: Int,
        title: String,
        hourOfDay: Int,
        minute: Int,
        repeatRule: Int,
        weekdays: List<Int>,
        scheduledDateMillis: Long?,
        advanceMinutes: Int,
        ringtone: String,
        volume: Int,
        snoozeMinutes: Int,
        snoozeCount: Int,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = System.currentTimeMillis() + snoozeMinutes * 60_000L
        val pi = buildPendingIntent(
            context, taskId, title,
            hourOfDay, minute, repeatRule, weekdays, scheduledDateMillis,
            advanceMinutes, ringtone, volume, true, snoozeMinutes,
            isSnooze = true, snoozeCount = snoozeCount,
            requestCode = snoozeRequestCode(taskId),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
            am.setWindow(AlarmManager.RTC_WAKEUP, triggerAt, 60_000L, pi)
        } else {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    /** 取消某任务的正常 + 贪睡闹钟 */
    fun cancelTaskAlarm(context: Context, taskId: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (code in listOf(normalRequestCode(taskId), snoozeRequestCode(taskId))) {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = AlarmReceiver.ACTION_ALARM
            }
            am.cancel(
                PendingIntent.getBroadcast(
                    context, code, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            )
        }
    }

    /** 是否拥有精确闹钟权限（API 31+；更低版本恒为 true） */
    fun canScheduleExactAlarms(context: Context): Boolean {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
    }

    /** T19：计算最近一次已过去的触发时刻（用于漏响检测）；无可补则 null */
    fun lastMissedTriggerMillis(
        nowMillis: Long, hourOfDay: Int, minute: Int,
        repeatRule: Int, weekdays: List<Int>, scheduledDateMillis: Long?, advanceMinutes: Int,
    ): Long? {
        val cal = Calendar.getInstance().apply { timeInMillis = nowMillis }
        cal.set(Calendar.HOUR_OF_DAY, hourOfDay)
        cal.set(Calendar.MINUTE, minute)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        cal.add(Calendar.MINUTE, -advanceMinutes)

        when (repeatRule) {
            REPEAT_ONCE -> {
                if (scheduledDateMillis != null) {
                    cal.timeInMillis = scheduledDateMillis
                    cal.set(Calendar.HOUR_OF_DAY, hourOfDay)
                    cal.set(Calendar.MINUTE, minute)
                    cal.set(Calendar.SECOND, 0)
                    cal.set(Calendar.MILLISECOND, 0)
                    cal.add(Calendar.MINUTE, -advanceMinutes)
                    return if (cal.timeInMillis <= nowMillis) cal.timeInMillis else null
                }
                return null
            }
            REPEAT_DAILY -> {
                if (cal.timeInMillis > nowMillis) cal.add(Calendar.DAY_OF_YEAR, -1)
                return cal.timeInMillis
            }
            REPEAT_WEEKLY -> {
                // Dart weekday: 1=周一...7=周日，Java: 1=周日...7=周六
                for (i in 0..7) {
                    val wd = cal.get(Calendar.DAY_OF_WEEK)
                    val dartWd = when (wd) {
                        Calendar.SUNDAY -> 7
                        Calendar.MONDAY -> 1
                        Calendar.TUESDAY -> 2
                        Calendar.WEDNESDAY -> 3
                        Calendar.THURSDAY -> 4
                        Calendar.FRIDAY -> 5
                        Calendar.SATURDAY -> 6
                        else -> 1
                    }
                    if (weekdays.contains(dartWd)) {
                        if (cal.timeInMillis <= nowMillis) return cal.timeInMillis
                    }
                    cal.add(Calendar.DAY_OF_YEAR, -1)
                }
                return null
            }
            else -> return null
        }
    }

    /** T19：WorkManager 周期扫描兜底——检查已过点但未补的闹钟，直接触发补响 */
    fun rescanMissedAlarms(context: Context): Int {
        val dbFile = java.io.File(context.filesDir, "efficiency_app.sqlite")
        if (!dbFile.exists()) return 0
        var db: android.database.sqlite.SQLiteDatabase? = null
        var compensated = 0
        val prefs = context.getSharedPreferences("alarm_rescan", Context.MODE_PRIVATE)
        try {
            db = android.database.sqlite.SQLiteDatabase.openDatabase(dbFile.absolutePath, null, android.database.sqlite.SQLiteDatabase.OPEN_READONLY)
            val now = System.currentTimeMillis()
            val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(now)
            val cursor = db.rawQuery(
                """
                SELECT sa.task_id, sa.hour, sa.minute, sa.repeat_rule, sa.weekdays,
                       sa.scheduled_date, sa.advance_minute, sa.ringtone, sa.volume,
                       sa.snooze_enabled, sa.snooze_minutes, tt.title
                FROM scheduled_alarms sa
                LEFT JOIN task_templates tt ON tt.id = sa.task_id
                """.trimIndent(), null
            )
            cursor.use { c ->
                while (c.moveToNext()) {
                    val taskId = c.getInt(c.getColumnIndexOrThrow("task_id"))
                    val hour = c.getInt(c.getColumnIndexOrThrow("hour"))
                    val minute = c.getInt(c.getColumnIndexOrThrow("minute"))
                    val repeatRuleStr = c.getString(c.getColumnIndexOrThrow("repeat_rule"))
                    val repeatRule = when (repeatRuleStr) {
                        "daily" -> REPEAT_DAILY
                        "weekly" -> REPEAT_WEEKLY
                        else -> REPEAT_ONCE
                    }
                    val weekdaysStr = c.getString(c.getColumnIndexOrThrow("weekdays"))
                    val weekdays = weekdaysStr?.split(",")?.filter { it.isNotEmpty() }?.map { it.toInt() } ?: emptyList()
                    val scheduledDateSec = c.getLong(c.getColumnIndexOrThrow("scheduled_date"))
                    val scheduledMillis = if (repeatRule == REPEAT_ONCE) scheduledDateSec * 1000 else null
                    val advanceMin = c.getInt(c.getColumnIndexOrThrow("advance_minute"))
                    val title = c.getString(c.getColumnIndexOrThrow("title")) ?: "任务提醒"

                    val lastMissed = lastMissedTriggerMillis(now, hour, minute, repeatRule, weekdays, scheduledMillis, advanceMin)
                    if (lastMissed != null && now - lastMissed < 2 * 60 * 60 * 1000) {
                        // 幂等标记：taskId+日期 唯一
                        val markKey = "compensated_${taskId}_$today"
                        if (prefs.getBoolean(markKey, false)) {
                            android.util.Log.i("AlarmRescan", "taskId=$taskId already compensated today, skip")
                            continue
                        }
                        val intent = Intent(context, AlarmService::class.java).apply {
                            action = AlarmReceiver.ACTION_ALARM
                            putExtra(EXTRA_TASK_ID, taskId)
                            putExtra(EXTRA_TITLE, title)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(intent)
                        } else {
                            context.startService(intent)
                        }
                        prefs.edit().putBoolean(markKey, true).commit()
                        compensated++
                        android.util.Log.i("AlarmRescan", "compensated taskId=$taskId lastMissed=$lastMissed")
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("AlarmRescan", "rescan failed: ${e.message}")
        } finally {
            db?.close()
        }
        return compensated
    }

    /** 构造带全部响铃参数的 PendingIntent（extra 供 Receiver / 全屏页读取） */
    private fun buildPendingIntent(
        context: Context,
        taskId: Int,
        title: String,
        hourOfDay: Int,
        minute: Int,
        repeatRule: Int,
        weekdays: List<Int>,
        scheduledDateMillis: Long?,
        advanceMinutes: Int,
        ringtone: String,
        volume: Int,
        snoozeEnabled: Boolean,
        snoozeMinutes: Int,
        isSnooze: Boolean,
        snoozeCount: Int,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM
            putExtra(EXTRA_TASK_ID, taskId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_HOUR, hourOfDay)
            putExtra(EXTRA_MINUTE, minute)
            putExtra(EXTRA_REPEAT_RULE, repeatRule)
            putExtra(EXTRA_WEEKDAYS, weekdays.toIntArray())
            putExtra(EXTRA_SCHEDULED_DATE, scheduledDateMillis ?: -1L)
            putExtra(EXTRA_ADVANCE, advanceMinutes)
            putExtra(EXTRA_RINGTONE, ringtone)
            putExtra(EXTRA_VOLUME, volume)
            putExtra(EXTRA_SNOOZE_ENABLED, snoozeEnabled)
            putExtra(EXTRA_SNOOZE_MINUTES, snoozeMinutes)
            putExtra(EXTRA_IS_SNOOZE, isSnooze)
            putExtra(EXTRA_SNOOZE_COUNT, snoozeCount)
        }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ---- Intent extra 常量（Receiver / AlarmFullScreenActivity 共用）----
    const val EXTRA_TASK_ID = "task_id"
    const val EXTRA_TITLE = "task_title"
    const val EXTRA_HOUR = "alarm_hour"
    const val EXTRA_MINUTE = "alarm_minute"
    const val EXTRA_REPEAT_RULE = "repeat_rule"
    const val EXTRA_WEEKDAYS = "weekdays"
    const val EXTRA_SCHEDULED_DATE = "scheduled_date"
    const val EXTRA_ADVANCE = "advance_minutes"
    const val EXTRA_RINGTONE = "ringtone"
    const val EXTRA_VOLUME = "volume"
    const val EXTRA_SNOOZE_ENABLED = "snooze_enabled"
    const val EXTRA_SNOOZE_MINUTES = "snooze_minutes"
    const val EXTRA_IS_SNOOZE = "is_snooze"
    const val EXTRA_SNOOZE_COUNT = "snooze_count"
}
