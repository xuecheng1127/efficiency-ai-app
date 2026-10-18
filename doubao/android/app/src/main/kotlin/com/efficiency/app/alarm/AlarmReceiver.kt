package com.efficiency.app.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 闹钟广播接收器（T13b：响铃解耦）
 *
 * 职责：
 * 1. 收到系统 AlarmManager 广播 → 启动 AlarmService（由服务负责响铃 + 发通知）
 * 2. 重复任务自持：非贪睡且为每日/每周重复时，依据原参数计算下一次触发并自动重排
 *
 * T13b 变更：不再直接发通知/响铃，全部交给 AlarmService。
 * 通知动作（贪睡/关闭）的 PendingIntent 直接指向 AlarmService，不经过本 Receiver。
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmReceiver"
        const val ACTION_ALARM = "com.efficiency.app.action.ALARM"
        const val ACTION_SNOOZE = "com.efficiency.app.action.SNOOZE"
        const val ACTION_DISMISS = "com.efficiency.app.action.DISMISS"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_ALARM -> handleAlarm(context, intent)
            else -> Log.w(TAG, "onReceive: unexpected action=${intent.action}, ignoring")
        }
    }

    private fun handleAlarm(context: Context, intent: Intent) {
        val taskId = intent.getIntExtra(AlarmScheduler.EXTRA_TASK_ID, -1)
        if (taskId < 0) return

        val isSnooze = intent.getBooleanExtra(AlarmScheduler.EXTRA_IS_SNOOZE, false)
        val repeatRule = intent.getIntExtra(AlarmScheduler.EXTRA_REPEAT_RULE, AlarmScheduler.REPEAT_ONCE)

        // 重复任务自持重排
        if (!isSnooze && repeatRule != AlarmScheduler.REPEAT_ONCE) {
            val next = AlarmScheduler.nextTriggerMillis(
                nowMillis = System.currentTimeMillis(),
                hourOfDay = intent.getIntExtra(AlarmScheduler.EXTRA_HOUR, 0),
                minute = intent.getIntExtra(AlarmScheduler.EXTRA_MINUTE, 0),
                repeatRule = repeatRule,
                weekdays = (intent.getIntArrayExtra(AlarmScheduler.EXTRA_WEEKDAYS) ?: intArrayOf()).toList(),
                scheduledDateMillis = intent.getLongExtra(AlarmScheduler.EXTRA_SCHEDULED_DATE, -1).let { if (it < 0) null else it },
                advanceMinutes = intent.getIntExtra(AlarmScheduler.EXTRA_ADVANCE, 0),
            )
            if (next != null) {
                AlarmScheduler.scheduleTaskAlarm(
                    context = context, taskId = taskId,
                    title = intent.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: "任务提醒",
                    triggerAtMillis = next,
                    hourOfDay = intent.getIntExtra(AlarmScheduler.EXTRA_HOUR, 0),
                    minute = intent.getIntExtra(AlarmScheduler.EXTRA_MINUTE, 0),
                    repeatRule = repeatRule,
                    weekdays = (intent.getIntArrayExtra(AlarmScheduler.EXTRA_WEEKDAYS) ?: intArrayOf()).toList(),
                    scheduledDateMillis = intent.getLongExtra(AlarmScheduler.EXTRA_SCHEDULED_DATE, -1).let { if (it < 0) null else it },
                    advanceMinutes = intent.getIntExtra(AlarmScheduler.EXTRA_ADVANCE, 0),
                    ringtone = intent.getStringExtra(AlarmScheduler.EXTRA_RINGTONE) ?: "晨曦",
                    volume = intent.getIntExtra(AlarmScheduler.EXTRA_VOLUME, 80),
                    snoozeEnabled = intent.getBooleanExtra(AlarmScheduler.EXTRA_SNOOZE_ENABLED, true),
                    snoozeMinutes = intent.getIntExtra(AlarmScheduler.EXTRA_SNOOZE_MINUTES, 5),
                )
            }
        }

        // T13b：启动 AlarmService，由服务负责响铃 + 发通知
        AlarmService.start(context, intent)
        Log.i(TAG, "alarm service started taskId=$taskId")
    }
}
