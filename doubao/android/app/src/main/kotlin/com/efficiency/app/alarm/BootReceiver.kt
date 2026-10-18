package com.efficiency.app.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.database.sqlite.SQLiteDatabase
import java.io.File

/**
 * 开机重建接收器（T11）
 *
 * 职责：设备重启后 AlarmManager 中的闹钟全部清空，从 scheduled_alarms 表
 * 全量读取并重建未完成闹钟。
 *
 * 存储策略：
 * - BOOT_COMPLETED（unlock 后）：credential-encrypted 存储可用，正常读库重建。
 * - LOCKED_BOOT_COMPLETED（direct boot 阶段）：credential-encrypted 存储不可用，
 *   数据库文件读不到，降级为直接返回（等 BOOT_COMPLETED 再处理）。
 *
 * 幂等：scheduleTaskAlarm 内部先 cancel 再 set，重复广播不会产生重复闹钟。
 * 已过期的 once：nextTriggerMillis 返回 null，跳过不排。
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
        private const val DB_NAME = "efficiency_app.sqlite"

        /** T12：前台兜底——重排全部已存闹钟（权限档位变化后由 MainActivity 调用） */
        @JvmStatic
        fun rebuildAlarms(context: Context) {
            val dbFile = File(context.filesDir, DB_NAME)
            if (!dbFile.exists()) {
                Log.w(TAG, "database not found at ${dbFile.absolutePath}, skip")
                return
            }

            var db: SQLiteDatabase? = null
            try {
                db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)

                val cursor = db.rawQuery(
                    """
                    SELECT sa.task_id, sa.hour, sa.minute, sa.repeat_rule, sa.weekdays,
                           sa.scheduled_date, sa.advance_minute, sa.ringtone, sa.volume,
                           sa.snooze_enabled, sa.snooze_minutes, tt.title
                    FROM scheduled_alarms sa
                    LEFT JOIN task_templates tt ON tt.id = sa.task_id
                    """.trimIndent(),
                    null
                )

                var rebuilt = 0
                var skipped = 0
                cursor.use { c ->
                    while (c.moveToNext()) {
                        val taskId = c.getInt(c.getColumnIndexOrThrow("task_id"))
                        val hour = c.getInt(c.getColumnIndexOrThrow("hour"))
                        val minute = c.getInt(c.getColumnIndexOrThrow("minute"))
                        val repeatRuleStr = c.getString(c.getColumnIndexOrThrow("repeat_rule"))
                        val weekdaysStr = c.getString(c.getColumnIndexOrThrow("weekdays"))
                        val scheduledDateSec = c.getLong(c.getColumnIndexOrThrow("scheduled_date"))
                        val advanceMin = c.getInt(c.getColumnIndexOrThrow("advance_minute"))
                        val ringtone = c.getString(c.getColumnIndexOrThrow("ringtone")) ?: "内置·晨曦"
                        val volume = c.getDouble(c.getColumnIndexOrThrow("volume")).toInt()
                        val snoozeEnabled = c.getInt(c.getColumnIndexOrThrow("snooze_enabled")) == 1
                        val snoozeMin = c.getInt(c.getColumnIndexOrThrow("snooze_minutes"))
                        val title = c.getString(c.getColumnIndexOrThrow("title")) ?: "任务提醒"

                        val repeatRule = when (repeatRuleStr) {
                            "daily" -> AlarmScheduler.REPEAT_DAILY
                            "weekly" -> AlarmScheduler.REPEAT_WEEKLY
                            else -> AlarmScheduler.REPEAT_ONCE
                        }
                        val weekdays = weekdaysStr?.split(",")?.filter { it.isNotEmpty() }?.map { it.toInt() } ?: emptyList()
                        val scheduledMillis = if (repeatRule == AlarmScheduler.REPEAT_ONCE) scheduledDateSec * 1000 else null

                        val trigger = AlarmScheduler.nextTriggerMillis(
                            nowMillis = System.currentTimeMillis(),
                            hourOfDay = hour,
                            minute = minute,
                            repeatRule = repeatRule,
                            weekdays = weekdays,
                            scheduledDateMillis = scheduledMillis,
                            advanceMinutes = advanceMin,
                        )

                        if (trigger == null) {
                            Log.i(TAG, "taskId=$taskId trigger null (once expired?), skip")
                            skipped++
                            continue
                        }

                        AlarmScheduler.scheduleTaskAlarm(
                            context = context,
                            taskId = taskId,
                            title = title,
                            triggerAtMillis = trigger,
                            hourOfDay = hour,
                            minute = minute,
                            repeatRule = repeatRule,
                            weekdays = weekdays,
                            scheduledDateMillis = scheduledMillis,
                            advanceMinutes = advanceMin,
                            ringtone = ringtone,
                            volume = volume,
                            snoozeEnabled = snoozeEnabled,
                            snoozeMinutes = snoozeMin,
                        )
                        rebuilt++
                        Log.i(TAG, "rebuilt taskId=$taskId \"$title\" trigger=$trigger")
                    }
                }
                Log.i(TAG, "rebuild complete: $rebuilt rebuilt, $skipped skipped")
            } catch (e: Exception) {
                Log.e(TAG, "rebuild failed: ${e.message}", e)
            } finally {
                db?.close()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                // T19修复：不要无条件降级。先试读库，读得到就直接重建。
                // 无安全锁屏的设备上，收到 LOCKED_BOOT_COMPLETED 时 userUnlocked 已是 true。
                val dbFile = File(context.filesDir, DB_NAME)
                if (dbFile.exists()) {
                    Log.i(TAG, "LOCKED_BOOT_COMPLETED: db readable, rebuilding directly")
                    rebuildAlarms(context)
                } else {
                    Log.i(TAG, "LOCKED_BOOT_COMPLETED: db not accessible, deferring to BOOT_COMPLETED")
                }
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.i(TAG, "BOOT_COMPLETED: rebuilding alarms from scheduled_alarms table")
                rebuildAlarms(context)
            }
        }
    }
}
