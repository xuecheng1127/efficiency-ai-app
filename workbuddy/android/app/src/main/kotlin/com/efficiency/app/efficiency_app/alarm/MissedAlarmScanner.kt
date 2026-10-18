package com.efficiency.app.efficiency_app.alarm

import android.content.Context

/**
 * B 档（近似档）的漏响补偿 —— T19 R1。
 *
 * ## 为什么需要它
 *
 * B 档用 `setWindow(60_000L)` 请求 60 秒窗口，但**实测系统给的是分钟级**：
 *
 * | 环境 | 请求 | 实得 |
 * |---|---|---|
 * | T10.5 模拟器 | 60s | 3m45s |
 * | T11 模拟器 | 60s | 4m18s |
 * | T11 模拟器 | 60s | 10m0s |
 * | T11 真机 | 60s | 2m4s |
 *
 * 也就是说：**没有精确闹钟权限时，闹钟会晚响，甚至被 Doze 推得很远**。
 * 本类负责周期性地找出「已经过了应响时刻、但没有任何迹象表明它响过」的记录，补一次。
 *
 * ## 判定「响过没有」靠什么
 *
 * [AlarmFireMarkers] 里每个 taskId 的「最近一次已处理时刻」：
 * - **正常响过**时 `AlarmReceiver` 会写它；
 * - **补响过**时本类会写它。
 *
 * 所以判据是 `handled < 候选应响时刻` ⇒ 漏响。这也**天然幂等**：补完立刻写标记，
 * 下一个周期再扫同一条已经被标记覆盖，不会重复补（R3）。
 *
 * ## 追溯窗口（为什么是 2 小时）
 *
 * 只补「最近 [LOOKBACK_MILLIS] 内」的漏响。理由：
 * - 周期最长 15 分钟，加 Doze 推迟，漏响通常在 1 小时内就能被发现；
 * - 2 小时足够覆盖「连续几个周期都没跑成」的情况；
 * - 再往前就没有提醒价值了（凌晨 3 点补响一个 20 点该响的闹钟只会烦人）。
 *
 * 这是一个**可以直接调的常量**，不是硬编码在逻辑里的魔数。
 *
 * ## 参数来源
 *
 * 只读 `scheduled_alarms`（`AlarmStore`，`OPEN_READONLY`）—— ADR-008 未被打破：
 * 本类**不写 drift 库**，留痕写在 [AlarmFireMarkers] 自己的 SharedPreferences 里。
 */
object MissedAlarmScanner {

    /** 追溯窗口：2 小时。 */
    const val LOOKBACK_MILLIS = 2 * 60 * 60_000L

    /** 一条被判定的漏响。 */
    data class Missed(
        val taskId: Int,
        val occurrenceMillis: Long,
        val lagMillis: Long,
    )

    /** 一次扫描的结果（计数单独带出来，便于日志与验收对账）。 */
    data class Outcome(val scanned: Int, val missed: List<Missed>)

    /**
     * 扫描出**该补而没补**的记录。**只读、无副作用**（不响铃、不写标记）。
     *
     * 拆成「扫描」与「补偿」两步是为了可测：扫描是纯判定，补偿才有副作用。
     */
    fun scan(context: Context, nowMillis: Long): Outcome {
        val records = AlarmStore.loadAllEnabled(context) // 只读（ADR-008）
        val missed = mutableListOf<Missed>()

        for (r in records) {
            val occurrence = AlarmOccurrence.mostRecentOccurrenceMillis(r, nowMillis)
            if (occurrence == null) {
                alarmLogScan("taskId=${r.taskId} skip: no past occurrence yet (rule=${r.repeatRule})")
                continue
            }
            val lag = nowMillis - occurrence
            if (lag > LOOKBACK_MILLIS) {
                alarmLogScan(
                    "taskId=${r.taskId} skip: past occurrence is outside lookback " +
                        "(lagMs=$lag > ${LOOKBACK_MILLIS}ms)",
                )
                continue
            }
            val handled = AlarmFireMarkers.lastHandledMillis(context, r.taskId)
            if (handled >= occurrence) {
                alarmLogScan(
                    "taskId=${r.taskId} skip: already handled (handled=$handled >= occurrence=$occurrence)",
                )
                continue
            }
            missed += Missed(r.taskId, occurrence, lag)
            alarmLogScan(
                "taskId=${r.taskId} MISSED: occurrence=$occurrence lagMs=$lag handled=$handled",
            )
        }

        return Outcome(records.size, missed)
    }

    /**
     * 补响。
     *
     * 响铃能力与正常到点**走同一条路**（[AlarmService.startRing] → 失败再退到通知），
     * 这样补响与正常响在行为上一致，不引入第二套响铃实现。
     *
     * **标记无论响铃是否成功都会写**：这是刻意的取舍 —— R3 要求的幂等优先级更高，
     * 「同一个漏响每 15 分钟重复骚扰一次」比「某次补响降级为只有通知」更糟。
     * 降级情况会以 `ringService=false` 出现在日志里，可被评审方核对。
     */
    fun compensate(context: Context, missed: List<Missed>): Int {
        var compensated = 0
        for (m in missed) {
            val started = try {
                AlarmService.startRing(context, m.taskId)
            } catch (e: Exception) {
                alarmLogError("compensate(taskId=${m.taskId}): startRing threw", e)
                false
            }
            if (!started) {
                alarmLogScan(
                    "compensate(taskId=${m.taskId}): ring service unavailable -> notification-only fallback",
                )
                AlarmNotifications.showAlarm(context, m.taskId)
            }
            AlarmFireMarkers.markHandled(context, m.taskId, m.occurrenceMillis)
            compensated++
            alarmLogScan(
                "compensated(taskId=${m.taskId}) occurrence=${m.occurrenceMillis} " +
                    "lagMs=${m.lagMillis} ringService=$started",
            )
        }
        return compensated
    }
}
