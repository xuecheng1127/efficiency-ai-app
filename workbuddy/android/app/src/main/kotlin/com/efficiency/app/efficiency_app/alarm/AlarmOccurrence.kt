package com.efficiency.app.efficiency_app.alarm

import java.util.Calendar

/**
 * 「最近一次**本该已经响过**的时刻」—— T19 周期扫描与「已响标记」共用的纯函数。
 *
 * ## 它和 [AlarmScheduler.nextTriggerMillis] 的关系
 *
 * `nextTriggerMillis` 算的是**未来**的下一次；本函数算的是**过去**的最近一次。
 * 两者必须共用同一套时间语义（本地零点、Dart weekday 1=周一…7=周日、once 不顺延），
 * 否则「响过了吗」会算错，周期扫描就会重复补响或漏补。
 *
 * **为什么把换算函数复制一份而不是改 `AlarmScheduler`**：`AlarmScheduler.kt` 是
 * T11 已验收通过的文件（`isExpiredOnce` / `nextTriggerMillis` 被真机日志核对过），
 * 在夜间窗口里为「换个可见性」而动它有回归风险。代价是 weekday/零点换算各有一份，
 * 所以契约测试里加了一条断言：**两份实现的 `Calendar.DAY_OF_WEEK` 映射必须逐字一致**，
 * 防止将来只改一边。
 */
object AlarmOccurrence {

    private const val DAY = 86_400_000L

    /**
     * 最近一次 ≤ [nowMillis] 的应响时刻；算不出来（例如 once 但 `scheduled_date` 还没到）返回 null。
     */
    fun mostRecentOccurrenceMillis(record: ScheduledAlarmRecord, nowMillis: Long): Long? {
        val todayAt = localMidnight(nowMillis) + record.hour * 3_600_000L + record.minute * 60_000L
        return when (record.repeatRule) {
            "once" -> {
                if (record.scheduledDateEpochSeconds == null) return null
                val dayStart = localMidnight(record.scheduledDateEpochSeconds * 1000L)
                val at = dayStart + record.hour * 3_600_000L + record.minute * 60_000L
                // 与 Dart 侧一致：once 就取 scheduled_date 那天的 hour:minute，即使已过点也不顺延
                if (at <= nowMillis) at else null
            }

            "weekly" -> {
                if (record.weekdays.isEmpty()) return mostRecentDaily(todayAt, nowMillis)
                for (i in 0..7) {
                    val candidate = todayAt - i * DAY
                    if (candidate <= nowMillis && dartWeekdayOf(candidate) in record.weekdays) return candidate
                }
                null
            }

            else -> mostRecentDaily(todayAt, nowMillis)
        }
    }

    private fun mostRecentDaily(todayAt: Long, nowMillis: Long): Long =
        if (todayAt <= nowMillis) todayAt else todayAt - DAY

    /** 本地时间当天 00:00 的时刻（与 [AlarmScheduler] 同实现）。 */
    internal fun localMidnight(millis: Long): Long {
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
     * `Calendar.DAY_OF_WEEK` 是 1=周日 … 7=周六 —— **必须显式换算**
     * （T01 规格禁止清单：禁止直接把 Calendar 的值当 Dart weekday 用）。
     */
    internal fun dartWeekdayOf(millis: Long): Int {
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
}
