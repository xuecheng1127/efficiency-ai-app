package com.efficiency.app.efficiency_app.alarm

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import java.io.File

/**
 * `scheduled_alarms` 表的一行（原生侧的只读视图）。
 *
 * **定案（ADR-008 / ADR-003）**：这张表是闹钟参数的**唯一真源**。
 * 原生侧不从 Intent extra 取参数，一律回到表里读 —— 这样进程被杀、
 * 设备重启之后参数不会丢（老实现把参数塞在 Intent extra 里，重启即全丢）。
 */
data class ScheduledAlarmRecord(
    val taskId: Int,
    val taskTitle: String,
    val hour: Int,
    val minute: Int,
    val repeatRule: String,
    /** 1=周一 … 7=周日（与 Dart `DateTime.weekday` 同语义，见 ADR / T01 规格） */
    val weekdays: List<Int>,
    /** 仅 once 有意义；drift 把 DateTime 存成 epoch **秒** */
    val scheduledDateEpochSeconds: Long?,
    val advanceMinutes: Int?,
    val ringtone: String,
    val volume: Int,
    val snoozeEnabled: Boolean,
    val snoozeMinutes: Int,
    val tier: String,
    val enabled: Boolean,
) {
    fun timeLabel(): String = "%02d:%02d".format(hour, minute)
}

/**
 * 只读读取 Flutter 侧的 drift 数据库（sqlite 文件）。
 *
 * 库路径与 Dart 侧 `AppDatabase.open()` 一致：
 * `getApplicationDocumentsDirectory()` → `<dataDir>/app_flutter/efficiency_app.sqlite`
 * （已在设备上实测：`/data/data/<pkg>/app_flutter/efficiency_app.sqlite`）。
 */
object AlarmStore {

    private const val DB_NAME = "efficiency_app.sqlite"

    /** 参数（含任务标题）都从表里取；标题来自 task_templates 的 LEFT JOIN。 */
    private const val SELECT_SQL = """
        SELECT a.task_id, a.hour, a.minute, a.repeat_rule, a.weekdays, a.scheduled_date,
               a.advance_minutes, a.ringtone, a.volume, a.snooze_enabled, a.snooze_minutes,
               a.tier, a.enabled, t.title AS task_title
        FROM scheduled_alarms a
        LEFT JOIN task_templates t ON t.id = a.task_id
    """

    private fun candidates(context: Context): List<File> = listOf(
        File(File(context.dataDir, "app_flutter"), DB_NAME),
        File(File(context.filesDir.parentFile, "app_flutter"), DB_NAME),
    )

    /**
     * 只读打开数据库。
     *
     * 实测本工程的 `journal_mode = delete`，可以直接只读打开；
     * 若将来改成 WAL 或遇到锁冲突，退化为「复制一份到 cache 再读」，保证原生侧不崩。
     */
    private fun openReadOnly(context: Context): SQLiteDatabase? {
        val cands = candidates(context)
        val src = cands.firstOrNull { it.exists() }
        if (src == null) {
            alarmLogError("db not found; tried=$cands")
            return null
        }
        return try {
            SQLiteDatabase.openDatabase(src.path, null, SQLiteDatabase.OPEN_READONLY)
        } catch (e: Exception) {
            alarmLog("direct open failed (${e.javaClass.simpleName}); falling back to a copy")
            try {
                val copy = File(context.cacheDir, "alarm_readonly_$DB_NAME")
                src.copyTo(copy, overwrite = true)
                for (suffix in listOf("-wal", "-shm")) {
                    val side = File(src.path + suffix)
                    if (side.exists()) side.copyTo(File(copy.path + suffix), overwrite = true)
                }
                SQLiteDatabase.openDatabase(copy.path, null, SQLiteDatabase.OPEN_READONLY)
            } catch (e2: Exception) {
                alarmLogError("copy open failed too", e2)
                null
            }
        }
    }

    /** 某任务的闹钟（表里 task_id 有 UNIQUE 约束，至多一条）。 */
    fun loadByTask(context: Context, taskId: Int): ScheduledAlarmRecord? =
        query(context, "$SELECT_SQL WHERE a.task_id = ? LIMIT 1", arrayOf(taskId.toString())).firstOrNull()

    /** 全部「参与重建」的闹钟 —— 表能独立回答这个问题，不依赖任何 Intent。 */
    fun loadAllEnabled(context: Context): List<ScheduledAlarmRecord> =
        query(context, "$SELECT_SQL WHERE a.enabled = 1 ORDER BY a.hour, a.minute", emptyArray())

    private fun query(context: Context, sql: String, args: Array<String>): List<ScheduledAlarmRecord> {
        val db = openReadOnly(context) ?: return emptyList()
        return try {
            db.rawQuery(sql, args).use { cursor ->
                buildList {
                    while (cursor.moveToNext()) add(read(cursor))
                }
            }
        } catch (e: Exception) {
            alarmLogError("query failed: $sql", e)
            emptyList()
        } finally {
            db.close()
        }
    }

    private fun read(cursor: Cursor): ScheduledAlarmRecord {
        fun index(name: String) = cursor.getColumnIndex(name)
        fun intOr(name: String, fallback: Int): Int {
            val i = index(name)
            return if (i < 0 || cursor.isNull(i)) fallback else cursor.getInt(i)
        }
        fun longOrNull(name: String): Long? {
            val i = index(name)
            return if (i < 0 || cursor.isNull(i)) null else cursor.getLong(i)
        }
        fun textOr(name: String, fallback: String): String {
            val i = index(name)
            return if (i < 0 || cursor.isNull(i)) fallback else cursor.getString(i)
        }

        val rawWeekdays = textOr("weekdays", "")
        val weekdays = rawWeekdays
            .split(',')
            .mapNotNull { it.trim().toIntOrNull() }
            .filter { it in 1..7 }
            .sorted()

        return ScheduledAlarmRecord(
            taskId = intOr("task_id", -1),
            taskTitle = textOr("task_title", "任务"),
            hour = intOr("hour", 0),
            minute = intOr("minute", 0),
            repeatRule = textOr("repeat_rule", "once"),
            weekdays = weekdays,
            scheduledDateEpochSeconds = longOrNull("scheduled_date"),
            advanceMinutes = longOrNull("advance_minutes")?.toInt(),
            ringtone = textOr("ringtone", "default"),
            volume = intOr("volume", 80),
            snoozeEnabled = intOr("snooze_enabled", 1) == 1,
            snoozeMinutes = intOr("snooze_minutes", 5),
            tier = textOr("tier", "inexact"),
            enabled = intOr("enabled", 1) == 1,
        )
    }
}
