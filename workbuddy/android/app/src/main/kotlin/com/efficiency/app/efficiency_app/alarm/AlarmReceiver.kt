package com.efficiency.app.efficiency_app.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 闹钟到点 / 通知动作的入口。
 *
 * **硬约束（v2.2 硬伤 1 定案）**：
 * 这里**不做 `context.startActivity(fullScreen)`**。
 * 到点只发通知，全屏页由 `Notification.setFullScreenIntent` 交给系统拉起。
 *
 * **T13b 改动**：到点之后**响铃不再由本广播接收者持有**，
 * 而是把「开始响」交给 `AlarmService`（生命周期独立于任何页面）。
 * 本类只负责：①交给服务响铃；②重复任务的自持重排（沿用原逻辑，未改）。
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val taskId = intent.getIntExtra(AlarmContract.EXTRA_TASK_ID, -1)
        alarmLog("onReceive action=$action taskId=$taskId")

        if (taskId <= 0) {
            alarmLogError("onReceive: missing/invalid taskId, ignored")
            return
        }

        when (action) {
            AlarmContract.ACTION_ALARM -> onAlarmFired(context, taskId, intent)
            // 兼容老版本的 PendingIntent（它们的动作指向本接收者）。
            // 行为与通知按钮一致：**转发给服务**，响铃的唯一归属者仍是 AlarmService。
            AlarmContract.ACTION_DISMISS -> AlarmService.sendControl(context, AlarmContract.ACTION_DISMISS, taskId)
            AlarmContract.ACTION_SNOOZE -> AlarmService.sendControl(context, AlarmContract.ACTION_SNOOZE, taskId)
            else -> alarmLog("onReceive: unhandled action=$action")
        }
    }

    /**
     * 到点：交给服务响铃（服务负责持有 `MediaPlayer` + 发前台通知）。
     *
     * 重复任务在这里**自持重排**下一次：参数仍在 `scheduled_alarms` 表里，
     * 重排复用同一条「读表 → 调度」的路径，不需要 App 常驻。
     * `repeat_rule = once` 不重排（否则同一个过去时刻会立刻再触发一次）。
     */
    private fun onAlarmFired(context: Context, taskId: Int, intent: Intent) {
        val isSnoozeReFire = intent.hasExtra(AlarmContract.EXTRA_SNOOZE_AT)

        // ① 先把响铃交出去（不要被后面的读表/重排拖慢）
        val started = AlarmService.startRing(context, taskId)
        if (!started) {
            // 前台服务与普通服务都被拒时，至少把通知挂出去：
            // 降级是「铃可能起不来」，而**不是**「静默什么都不做」。
            alarmLog("onAlarmFired(taskId=$taskId): DEGRADED - service refused, fall back to notification-only")
            AlarmNotifications.showAlarm(context, taskId)
        }

        // ② 重复任务自持重排（沿用 T10.5/T13 的原逻辑，未改）
        // 说明：Intent extra 里只有 taskId（定位用），**所有闹钟参数一律来自表**（ADR-008）。
        val record = AlarmStore.loadByTask(context, taskId)
        if (record == null) {
            alarmLog("onAlarmFired(taskId=$taskId): no row in scheduled_alarms; notification used fallback text only")
        } else if (!isSnoozeReFire && record.repeatRule != "once") {
            val next = AlarmScheduler.nextTriggerMillis(record, System.currentTimeMillis())
            AlarmScheduler.schedule(context, taskId, next, true)
        } else {
            alarmLog(
                "onAlarmFired(taskId=$taskId): repeatRule=${record.repeatRule} snoozeReFire=$isSnoozeReFire -> no re-arm",
            )
        }

        // ③ T19：**正常响过也要留痕**。
        // 周期扫描靠「已处理时刻 < 候选应响时刻」判定漏响，如果正常响不写标记，
        // 扫描会把每一次正常响都当成漏响再补一遍。这里写标记 = 告诉扫描器
        // 「这一次已经处理过了」。
        if (record != null) {
            val occurrence = AlarmOccurrence.mostRecentOccurrenceMillis(record, System.currentTimeMillis())
            if (occurrence == null) {
                alarmLog("onAlarmFired(taskId=$taskId): no computable occurrence -> skip T19 marker")
            } else {
                AlarmFireMarkers.markHandled(context, taskId, occurrence)
            }
        }
    }
}
