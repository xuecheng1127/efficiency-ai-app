package com.efficiency.app.efficiency_app.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.efficiency.app.efficiency_app.R

/**
 * 闹钟通知（含全屏 Intent）。
 *
 * **硬约束（v2.2 硬伤 1 定案）**：到点一律走
 * `Notification.setFullScreenIntent(pendingIntent, true)`，
 * **禁止无条件 `context.startActivity(fullScreen)`** —— Android 10+ 后台启动 Activity 受限，
 * 国产 ROM 上会被**静默**拦截（表现为「闹钟到点但没响」且没有任何报错）。
 *
 * **T13b 改动**：通知的「贪睡 / 关闭」两个动作不再发给 `AlarmReceiver`，
 * 而是**直接发给 `AlarmService`** —— 停铃的唯一归属者是服务，动作不该绕一圈回到广播。
 * 渠道 / `category=alarm` / `IMPORTANCE_HIGH` / 全屏 Intent 全部保持原样（T13b R4）。
 */
object AlarmNotifications {

    /** 创建通知渠道（Android 8+ 必需）。渠道建好后其属性不可改，故每次都尝试创建（幂等）。 */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(AlarmContract.NOTIFICATION_CHANNEL_ID) != null) return

        val audioAttributes = AudioAttributes.Builder()
            // USAGE_ALARM：走闹钟音量流，静音/勿扰下也能响（否则会归到媒体流）
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            AlarmContract.NOTIFICATION_CHANNEL_ID,
            "任务闹钟",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "任务到点提醒（全屏响铃）"
            setSound(alarmSoundUri(context), audioAttributes)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 400, 500)
            // 绕过勿扰：真正生效需要 ACCESS_NOTIFICATION_POLICY（属「专注模式」的权限流程，本任务不申请）
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
        alarmLog("notification channel created: ${AlarmContract.NOTIFICATION_CHANNEL_ID} (IMPORTANCE_HIGH, USAGE_ALARM)")
    }

    /** 通知里的铃音（渠道音 + 全屏页自带循环播放都指向同一个资源）。 */
    fun alarmSoundUri(context: Context): Uri =
        Uri.parse("android.resource://${context.packageName}/${R.raw.alarm_gentle}")

    /**
     * 构造到点通知（**不发送**）。
     *
     * 抽成独立函数是 T13b 的要求：通知要作为**前台服务的通知**由 `startForeground` 立即挂上，
     * 因此必须能「先构造、再由调用方决定怎么发」（`startForeground` 或 `notify`）。
     *
     * 参数（标题 / 时点 / 音量）全部从 `scheduled_alarms` + `task_templates` 读取，不走 Intent extra。
     */
    fun buildAlarmNotification(context: Context, taskId: Int): Notification {
        ensureChannel(context)

        val record = AlarmStore.loadByTask(context, taskId)
        val title = record?.taskTitle ?: "任务提醒"
        val timeText = record?.timeLabel().orEmpty()

        val compat = NotificationManagerCompat.from(context)
        val notificationsEnabled = compat.areNotificationsEnabled()
        val canFullScreen = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
        } else {
            true
        }

        val fullScreenPi = PendingIntent.getActivity(
            context,
            AlarmContract.fullScreenRequestCode(taskId),
            AlarmFullScreenActivity.newIntent(context, taskId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // T13b：动作直接打到服务（不再是 broadcast 给 AlarmReceiver）
        val snoozePi = PendingIntent.getService(
            context,
            AlarmContract.snoozeRequestCode(taskId),
            AlarmService.controlIntent(context, AlarmContract.ACTION_SNOOZE, taskId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val dismissPi = PendingIntent.getService(
            context,
            AlarmContract.dismissRequestCode(taskId),
            AlarmService.controlIntent(context, AlarmContract.ACTION_DISMISS, taskId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, AlarmContract.NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_alarm_notification)
            .setContentTitle(title)
            .setContentText(if (timeText.isEmpty()) "闹钟时间到" else "$timeText · 闹钟时间到")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            // ★ 关键：全屏靠 FullScreenIntent，不靠 startActivity
            .setFullScreenIntent(fullScreenPi, true)
            .setContentIntent(fullScreenPi)
            .addAction(R.drawable.ic_alarm_notification, "贪睡", snoozePi)
            .addAction(R.drawable.ic_alarm_notification, "关闭", dismissPi)
            .build()

        if (!notificationsEnabled) {
            alarmLog(
                "show(taskId=$taskId): WARNING notifications are DISABLED " +
                    "(POST_NOTIFICATIONS not granted) -> the notification will not be shown at all",
            )
        }
        alarmLog(
            "show(taskId=$taskId) title=\"$title\" canUseFullScreenIntent=$canFullScreen " +
                "(false => 系统只显示悬浮通知、不自动拉起全屏页；是否授予由 USE_FULL_SCREEN_INTENT 决定)",
        )

        return notification
    }

    /** 发送通知（降级路径 / 非前台服务场景使用）。 */
    fun post(context: Context, taskId: Int, notification: Notification) {
        try {
            NotificationManagerCompat.from(context).notify(AlarmContract.notificationId(taskId), notification)
        } catch (e: SecurityException) {
            alarmLogError("post(taskId=$taskId): notify failed", e)
        }
    }

    /**
     * 到点：构造 + 发送通知（`setFullScreenIntent` 在里面）。
     *
     * T13b 之后这条路径**只作为降级兜底**（前台服务起不来时至少把通知挂出去）；
     * 正常路径由 `AlarmService` 用同一份 `buildAlarmNotification` 作为前台通知发出。
     */
    fun showAlarm(context: Context, taskId: Int) {
        post(context, taskId, buildAlarmNotification(context, taskId))
    }

    /** 撤销该任务的通知（关闭 / 贪睡 / 超时 / 取消闹钟时调用）。 */
    fun cancel(context: Context, taskId: Int) {
        NotificationManagerCompat.from(context).cancel(AlarmContract.notificationId(taskId))
    }
}
