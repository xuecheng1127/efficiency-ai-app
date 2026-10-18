package com.efficiency.app.alarm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.efficiency.app.R

/**
 * 闹钟响铃前台服务（T13b：响铃与 Activity 解耦）
 *
 * 核心职责：
 * - 持有 MediaPlayer 循环响铃，生命周期独立于 Activity
 * - 发前台通知（带 setFullScreenIntent 拉起全屏页）
 * - AUTO_STOP 5 分钟自动停铃
 * - 处理贪睡/关闭动作
 *
 * 为什么用前台服务：
 * - Activity 被 ROM 销毁时（熄屏锁屏场景），铃必须继续响
 * - 前台服务带 ONGOING 通知，系统不会轻易杀掉
 */
class AlarmService : Service() {

    companion object {
        private const val TAG = "AlarmService"
        const val CHANNEL_ID = "alarm_channel"
        const val CHANNEL_NAME = "任务闹钟"

        const val ACTION_ALARM = "com.efficiency.app.action.ALARM"
        const val ACTION_SNOOZE = "com.efficiency.app.action.SNOOZE"
        const val ACTION_DISMISS = "com.efficiency.app.action.DISMISS"

        /** AUTO_STOP 超时：5 分钟 */
        private const val AUTO_STOP_DELAY_MS = 5 * 60 * 1000L

        /** 通知 ID（用 taskId 做通知 ID，贪睡/关闭动作 cancel 时对应） */
        private const val NOTIFICATION_ID_BASE = 10000

        fun start(context: Context, intent: Intent) {
            val serviceIntent = Intent(context, AlarmService::class.java).apply {
                action = ACTION_ALARM
                putExtras(intent)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.i(TAG, "service started")
        }

        fun stop(context: Context, taskId: Int, action: String) {
            val serviceIntent = Intent(context, AlarmService::class.java).apply {
                this.action = action
                putExtra(AlarmScheduler.EXTRA_TASK_ID, taskId)
            }
            context.startService(serviceIntent)
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentTaskId: Int = -1
    private var isPlaying = false

    /** AUTO_STOP 任务 */
    private val autoStopRunnable = Runnable {
        Log.w(TAG, "AUTO_STOP triggered, stopping ringtone")
        stopRingtoneAndNotification()
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_ALARM -> handleAlarm(intent)
            ACTION_SNOOZE -> handleSnooze(intent)
            ACTION_DISMISS -> handleDismiss(intent)
            else -> Log.w(TAG, "onStartCommand: unknown action=${intent?.action}")
        }
        return START_NOT_STICKY
    }

    /**
     * ADR-008：参数一律回表读，不走 Intent extra。
     *
     * 设计说明：把回表结果【合并进 intent】而不是改造下游签名 ——
     * 这样 startForegroundWithNotification / startRingtone / 贪睡重排 / 全屏页
     * 四条下游路径都自动拿到正确参数，改动面最小。
     *
     * 为什么必须做：补偿路径（AlarmScheduler.rescanMissedAlarms）只带
     * EXTRA_TASK_ID + EXTRA_TITLE，若不回表，铃会退回默认「晨曦 / 80%」，
     * 与用户在设置页选的铃声、音量不符。
     *
     * 口诀：DB 有的以 DB 为准；DB 取不到（记录已删）才退回 Intent，并【打日志说明】，不静默。
     */
    private fun enrichFromDb(intent: Intent, taskId: Int) {
        val dbFile = java.io.File(filesDir, "efficiency_app.sqlite")
        if (!dbFile.exists()) {
            Log.w(TAG, "params fallback to Intent extra taskId=$taskId (db file missing)")
            return
        }
        var db: android.database.sqlite.SQLiteDatabase? = null
        try {
            db = android.database.sqlite.SQLiteDatabase.openDatabase(
                dbFile.absolutePath, null, android.database.sqlite.SQLiteDatabase.OPEN_READONLY,
            )
            db.rawQuery(
                "SELECT sa.ringtone, sa.volume, sa.snooze_enabled, sa.snooze_minutes, " +
                "       sa.hour, sa.minute, sa.repeat_rule, sa.weekdays, sa.scheduled_date, " +
                "       sa.advance_minute, tt.title " +
                "FROM scheduled_alarms sa " +
                "LEFT JOIN task_templates tt ON tt.id = sa.task_id " +
                "WHERE sa.task_id = ?",
                arrayOf(taskId.toString()),
            ).use { c ->
                if (!c.moveToFirst()) {
                    Log.w(TAG, "params fallback to Intent extra taskId=$taskId (row missing)")
                    return
                }
                val ringtone = c.getString(c.getColumnIndexOrThrow("ringtone")) ?: "晨曦"
                val volume = c.getInt(c.getColumnIndexOrThrow("volume")).coerceIn(0, 100)
                val title = c.getString(c.getColumnIndexOrThrow("title")) ?: "任务提醒"
                val snoozeEnabled = c.getInt(c.getColumnIndexOrThrow("snooze_enabled")) != 0
                val snoozeMinutes = c.getInt(c.getColumnIndexOrThrow("snooze_minutes"))
                val hour = c.getInt(c.getColumnIndexOrThrow("hour"))
                val minute = c.getInt(c.getColumnIndexOrThrow("minute"))
                val advanceMin = c.getInt(c.getColumnIndexOrThrow("advance_minute"))
                val scheduledSec = c.getLong(c.getColumnIndexOrThrow("scheduled_date"))
                val repeatRule = when (c.getString(c.getColumnIndexOrThrow("repeat_rule"))) {
                    "daily" -> AlarmScheduler.REPEAT_DAILY
                    "weekly" -> AlarmScheduler.REPEAT_WEEKLY
                    else -> AlarmScheduler.REPEAT_ONCE
                }
                val weekdays = (c.getString(c.getColumnIndexOrThrow("weekdays"))
                    ?.split(",")?.filter { it.isNotEmpty() }?.map { it.toInt() }
                    ?: emptyList()).toIntArray()

                intent.putExtra(AlarmScheduler.EXTRA_TITLE, title)
                intent.putExtra(AlarmScheduler.EXTRA_RINGTONE, ringtone)
                intent.putExtra(AlarmScheduler.EXTRA_VOLUME, volume)
                intent.putExtra(AlarmScheduler.EXTRA_SNOOZE_ENABLED, snoozeEnabled)
                intent.putExtra(AlarmScheduler.EXTRA_SNOOZE_MINUTES, snoozeMinutes)
                intent.putExtra(AlarmScheduler.EXTRA_HOUR, hour)
                intent.putExtra(AlarmScheduler.EXTRA_MINUTE, minute)
                intent.putExtra(AlarmScheduler.EXTRA_ADVANCE, advanceMin)
                intent.putExtra(AlarmScheduler.EXTRA_REPEAT_RULE, repeatRule)
                intent.putExtra(AlarmScheduler.EXTRA_WEEKDAYS, weekdays)
                intent.putExtra(AlarmScheduler.EXTRA_SCHEDULED_DATE, scheduledSec * 1000)
                Log.i(TAG, "params from DB taskId=$taskId ringtone=$ringtone volume=$volume")
            }
        } catch (e: Exception) {
            Log.e(TAG, "loadAlarmParams failed taskId=$taskId", e)
        } finally {
            db?.close()
        }
    }

    private fun handleAlarm(intent: Intent) {
        val taskId = intent.getIntExtra(AlarmScheduler.EXTRA_TASK_ID, -1)
        if (taskId < 0) {
            Log.w(TAG, "handleAlarm: invalid taskId, stopping")
            stopSelf()
            return
        }
        currentTaskId = taskId

        // 0. ADR-008：参数一律回表读（Intent 只带 taskId 作为主键）
        enrichFromDb(intent, taskId)

        // 1. 启动前台服务 + 发通知
        startForegroundWithNotification(intent)

        // 2. 开始响铃
        startRingtone(intent)

        // 3. 启动 AUTO_STOP 定时器
        mainHandler.removeCallbacks(autoStopRunnable)
        mainHandler.postDelayed(autoStopRunnable, AUTO_STOP_DELAY_MS)

        Log.i(TAG, "alarm started taskId=$taskId")
    }

    private fun handleSnooze(intent: Intent) {
        Log.i(TAG, "snooze action received")
        // 停铃 + 撤通知
        stopRingtoneAndNotification()

        // 重排贪睡闹钟
        val taskId = intent.getIntExtra(AlarmScheduler.EXTRA_TASK_ID, -1)
        if (taskId >= 0) {
            val snoozeMinutes = intent.getIntExtra(AlarmScheduler.EXTRA_SNOOZE_MINUTES, 5)
            val snoozeCount = intent.getIntExtra(AlarmScheduler.EXTRA_SNOOZE_COUNT, 0)
            AlarmScheduler.scheduleSnoozeAlarm(
                context = this,
                taskId = taskId,
                title = intent.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: "任务提醒",
                hourOfDay = intent.getIntExtra(AlarmScheduler.EXTRA_HOUR, 0),
                minute = intent.getIntExtra(AlarmScheduler.EXTRA_MINUTE, 0),
                repeatRule = intent.getIntExtra(AlarmScheduler.EXTRA_REPEAT_RULE, AlarmScheduler.REPEAT_ONCE),
                weekdays = (intent.getIntArrayExtra(AlarmScheduler.EXTRA_WEEKDAYS) ?: intArrayOf()).toList(),
                scheduledDateMillis = intent.getLongExtra(AlarmScheduler.EXTRA_SCHEDULED_DATE, -1).let { if (it < 0) null else it },
                advanceMinutes = intent.getIntExtra(AlarmScheduler.EXTRA_ADVANCE, 0),
                ringtone = intent.getStringExtra(AlarmScheduler.EXTRA_RINGTONE) ?: "晨曦",
                volume = intent.getIntExtra(AlarmScheduler.EXTRA_VOLUME, 80),
                snoozeMinutes = snoozeMinutes,
                snoozeCount = snoozeCount + 1,
            )
            Log.i(TAG, "snooze rescheduled taskId=$taskId ${snoozeMinutes}min count=${snoozeCount + 1}")
        }
        stopSelf()
    }

    private fun handleDismiss(intent: Intent) {
        Log.i(TAG, "dismiss action received")
        stopRingtoneAndNotification()
        stopSelf()
    }

    private fun startForegroundWithNotification(intent: Intent) {
        val taskId = intent.getIntExtra(AlarmScheduler.EXTRA_TASK_ID, -1)
        val title = intent.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: "任务提醒"
        val snoozeEnabled = intent.getBooleanExtra(AlarmScheduler.EXTRA_SNOOZE_ENABLED, true)
        val snoozeCount = intent.getIntExtra(AlarmScheduler.EXTRA_SNOOZE_COUNT, 0)

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createChannel(nm)

        // 全屏 Intent：PendingIntent 指向 AlarmFullScreenActivity（T13 路径保持不变）
        val fullScreenIntent = Intent(this, AlarmFullScreenActivity::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtras(intent)
        }
        val fullScreenPi = PendingIntent.getActivity(
            this, taskId * 100 + 1, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("效率助手")
            .setContentText(title)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)  // 前台通知不能 autoCancel，要等服务 stopSelf
            .setOngoing(true)
            .setFullScreenIntent(fullScreenPi, true)
            .setContentIntent(fullScreenPi)

        // 贪睡动作：PendingIntent 指向 AlarmService
        if (snoozeEnabled && snoozeCount < 3) {
            val snoozeIntent = Intent(this, AlarmService::class.java).apply {
                action = ACTION_SNOOZE
                putExtras(intent)
            }
            val snoozePi = PendingIntent.getService(
                this, taskId * 100 + 2, snoozeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            builder.addAction(android.R.drawable.ic_media_pause, "贪睡", snoozePi)
        }

        // 关闭动作：PendingIntent 指向 AlarmService
        val dismissIntent = Intent(this, AlarmService::class.java).apply {
            action = ACTION_DISMISS
            putExtra(AlarmScheduler.EXTRA_TASK_ID, taskId)
        }
        val dismissPi = PendingIntent.getService(
            this, taskId * 100 + 3, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "关闭", dismissPi)

        val notification = builder.build()
        val notificationId = NOTIFICATION_ID_BASE + taskId
        // T17: 尝试前台服务；失败则降级为普通通知（DEGRADED_NO_FGS）
        var fgsOk = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(notificationId, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(notificationId, notification)
            }
            fgsOk = true
            Log.i(TAG, "foreground notification shown taskId=$taskId type=mediaPlayback")
        } catch (e: Exception) {
            // 后台启动 FGS 被系统拒绝（Android 12+ / 14 mediaPlayback 限制）
            // 降级：发普通高优先级通知，铃继续响（虽然不是 FGS，但至少通知和铃都在）
            Log.w(TAG, "DEGRADED_NO_FGS: startForeground failed, fallback to notify()", e)
            try {
                nm.notify(notificationId, notification)
                Log.i(TAG, "degraded notification posted taskId=$taskId")
            } catch (e2: Exception) {
                Log.e(TAG, "degraded notify also failed", e2)
            }
        }
    }

    private fun startRingtone(intent: Intent) {
        val volume = intent.getIntExtra(AlarmScheduler.EXTRA_VOLUME, 80).coerceIn(0, 100)
        val ringtone = intent.getStringExtra(AlarmScheduler.EXTRA_RINGTONE) ?: "晨曦"
        val resId = when (ringtone) {
            "微风" -> R.raw.alarm_tone_2
            "雨落" -> R.raw.alarm_tone_3
            else -> R.raw.alarm_tone_1
        }

        try {
            val player = MediaPlayer()
            val afd = resources.openRawResourceFd(resId)
            player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            player.isLooping = true
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            player.setOnPreparedListener { mp ->
                val targetVolume = volume / 100f
                // 前 3 秒渐强
                val steps = 30
                var i = 0
                mainHandler.post(object : Runnable {
                    override fun run() {
                        i++
                        if (i <= steps) {
                            val frac = i.toFloat() / steps
                            mp.setVolume(targetVolume * frac, targetVolume * frac)
                            mainHandler.postDelayed(this, 100)
                        } else {
                            mp.setVolume(targetVolume, targetVolume)
                        }
                    }
                })
                mp.start()
                isPlaying = true
                Log.i(TAG, "ringtone started")
            }
            mediaPlayer = player
            player.prepareAsync()
        } catch (e: Exception) {
            // 降级为系统默认闹钟音
            try {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                if (uri != null) {
                    mediaPlayer = MediaPlayer.create(this, uri)
                    mediaPlayer?.isLooping = true
                    mediaPlayer?.start()
                    isPlaying = true
                }
            } catch (_: Exception) {
                Log.e(TAG, "ringtone playback failed")
            }
        }
    }

    private fun stopRingtoneAndNotification() {
        // 停铃
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        mediaPlayer?.release()
        mediaPlayer = null
        isPlaying = false

        // 撤通知
        if (currentTaskId >= 0) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID_BASE + currentTaskId)
            Log.i(TAG, "notification cancelled taskId=$currentTaskId")
        }

        // 移除 AUTO_STOP 回调
        mainHandler.removeCallbacks(autoStopRunnable)
    }

    private fun createChannel(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "任务闹钟响铃通知"
                setBypassDnd(true)
                enableVibration(true)
            }
            nm.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        Log.i(TAG, "service destroyed")
        stopRingtoneAndNotification()
        super.onDestroy()
    }
}
