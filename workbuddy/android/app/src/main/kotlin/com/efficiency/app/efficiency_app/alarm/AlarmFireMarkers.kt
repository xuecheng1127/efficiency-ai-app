package com.efficiency.app.efficiency_app.alarm

import android.content.Context

/**
 * 「这一次已经处理过了」的留痕（T19 R3 · 幂等）。
 *
 * ## 为什么用 SharedPreferences，而不是给 `scheduled_alarms` 加一列
 *
 * 规格允许「用 `updated_at` 或新列，但改 schema 需说明并给迁移」。我选择**不改 schema**：
 *
 * 1. **ADR-008 定案：`scheduled_alarms` 是原生侧的只读真源**（`AlarmStore` 只以
 *    `OPEN_READONLY` 打开，T11-7 契约测试守着这一点）。让原生 Worker 去写这张表
 *    等于推翻那条定案 —— 而它正是「参数不丢、单一真源」的地基。
 * 2. 夜间窗口里动 schema 要连带改 drift 的 `schemaVersion` + 写迁移 + 清库重建，
 *    风险与收益不成比例；V1.0 未发布，本来也没有真实用户数据需要迁移。
 * 3. 这个标记**不是闹钟配置**，而是「扫描器自己的运行痕迹」—— 归扫描器自己存更自然：
 *    它随包卸载/清数据一起消失（那之后本来也该重新评估），不会污染用户数据。
 *
 * ## 语义
 *
 * 每个 taskId 只存**一个** Long：最近一次「已处理」（正常响过 **或** 被补响过）的
 * 应响时刻。判定幂等时比较 `标记 < 本次候选时刻` 即视为漏响。
 *
 * **只前进不回退**：`markHandled` 只在更大的时刻上写入，避免乱序调用把标记改小后
 * 造成重复补响。时钟回拨/重装会丢标记 —— 这个边界在报告里标注了。
 */
object AlarmFireMarkers {

    private const val PREFS_NAME = "alarm_fire_markers"
    private const val KEY_PREFIX = "handled_occurrence_"

    private fun key(taskId: Int) = "$KEY_PREFIX$taskId"

    /** 最近一次已处理的应响时刻；从未处理过返回 0。 */
    fun lastHandledMillis(context: Context, taskId: Int): Long =
        prefs(context).getLong(key(taskId), 0L)

    /**
     * 标记「该时刻已经处理过」。
     *
     * 用 `commit()` 而不是 `apply()`：Worker 可能在写入后很快被系统回收，
     * 这一步的正确性直接决定幂等，不能异步化。
     */
    fun markHandled(context: Context, taskId: Int, occurrenceMillis: Long): Boolean {
        val current = lastHandledMillis(context, taskId)
        if (occurrenceMillis <= current) {
            // 只前进不回退：这是一条**幂等保护的日志**，出现它说明有人试图把标记改小
            alarmLogScan(
                "marker kept(taskId=$taskId): existing=$current >= incoming=$occurrenceMillis (no backwards write)",
            )
            return false
        }
        val ok = prefs(context).edit().putLong(key(taskId), occurrenceMillis).commit()
        alarmLogScan("marker saved(taskId=$taskId) handled=$occurrenceMillis committed=$ok")
        return ok
    }

    /** 清除某任务的标记（取消闹钟 / 重置时用）。 */
    fun clear(context: Context, taskId: Int) {
        prefs(context).edit().remove(key(taskId)).commit()
        alarmLogScan("marker cleared(taskId=$taskId)")
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
