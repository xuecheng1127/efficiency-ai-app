package com.efficiency.app.efficiency_app.alarm

import android.util.Log

/**
 * 闹钟模块常量与日志。
 *
 * 日志统一带 `[T10.5][alarm-native]` 前缀，便于评审方直接过滤：
 *   adb -s emulator-5554 logcat -d | findstr "alarm-native"
 */
object AlarmContract {

    /** 与 Dart 侧 [lib/core/platform/alarm_channel.dart] 逐字一致 —— 这是已定契约，不得改动。 */
    const val CHANNEL = "efficiency_app/alarm"

    /** 到点触发（由 AlarmManager 的 PendingIntent 发出） */
    const val ACTION_ALARM = "com.efficiency.app.efficiency_app.action.ALARM"

    /** 通知上的「关闭」 */
    const val ACTION_DISMISS = "com.efficiency.app.efficiency_app.action.DISMISS"

    /** 通知上的「贪睡」 */
    const val ACTION_SNOOZE = "com.efficiency.app.efficiency_app.action.SNOOZE"

    const val EXTRA_TASK_ID = "task_id"

    /** 贪睡的一次性触发时刻（毫秒）。只是本次运行的临时值，**不落库**。 */
    const val EXTRA_SNOOZE_AT = "snooze_at_millis"

    const val NOTIFICATION_CHANNEL_ID = "task_alarm"

    // ===================== T13b：响铃与页面解耦 =====================

    /**
     * 「让服务开始响」的应用内动作（`AlarmReceiver` 收到到点广播后发给 `AlarmService`）。
     *
     * 与 [ACTION_ALARM] 刻意分开：前者是**系统投递的闹钟到点广播**，
     * 后者是**应用内部指令**。混用会让日志和 T14 的来源校验都变模糊。
     */
    const val ACTION_RING = "com.efficiency.app.efficiency_app.action.RING"

    /**
     * 响铃上限（T13b R2 规格：5 分钟），超时自动停铃 + 撤通知。
     *
     * **由 `AlarmService` 持有，不再挂在 Activity 上**：真机实测（T14 复验）Activity 会在
     * `onResume` 后约 50ms 被 ROM 销毁，超时兜底挂在它身上会随页面一起消失。
     */
    const val AUTO_STOP_MILLIS = 5 * 60_000L

    /**
     * 服务存活心跳间隔。
     *
     * 用途是**证据**：证明「页面已经被销毁、服务侧仍在响」（T13b 验收 #3 / #4）。
     * 没有它，评审方只能靠"没有停止日志"反推，不够硬。
     */
    const val HEARTBEAT_MILLIS = 10_000L

    /**
     * **测试专用**：覆盖响铃上限（毫秒）。
     *
     * 正式路径（`AlarmReceiver`）**永不设置**该 extra —— 只有 adb 直接给服务发命令时才会用，
     * 且服务收到后会打一条 `WARNING ... TEST SEAM` 日志，避免被误认成线上行为。
     * 用途：不重新构建就能验证 AUTO_STOP（T13b 验收 #5）。
     */
    const val EXTRA_AUTO_STOP_MS = "auto_stop_override_ms"

    /**
     * 降级标记：前台服务被系统拒绝启动时，`AlarmReceiver` 用普通 `startService` 重投。
     * 服务看到这一位就**不调用 `startForeground`**（否则会因为缺前台身份而崩），
     * 改为「只发高优先级通知 + 在后台服务里响铃」。
     */
    const val EXTRA_DEGRADED_NO_FGS = "degraded_no_fgs"

    /** 通知 id。沿用既有约定：一次响铃 = 一个 taskId = 一个通知 id。 */
    fun notificationId(taskId: Int): Int = taskId

    /**
     * PendingIntent 的 requestCode 分段。
     *
     * [taskId] 本身唯一，所以主闹钟直接用 taskId；
     * 同一任务的其它 PendingIntent（全屏 / 关闭 / 贪睡）错开固定偏移，
     * 保证「一个任务一套、任务之间不串」。
     */
    private const val SEGMENT = 100_000

    fun alarmRequestCode(taskId: Int): Int = taskId
    fun fullScreenRequestCode(taskId: Int): Int = taskId + SEGMENT
    fun dismissRequestCode(taskId: Int): Int = taskId + SEGMENT * 2
    fun snoozeRequestCode(taskId: Int): Int = taskId + SEGMENT * 3
}

private const val LOG_TAG = "T10.5"

/** 原生闹钟层统一日志出口。 */
internal fun alarmLog(message: String) {
    Log.i(LOG_TAG, "[T10.5][alarm-native] $message")
}

/** 原生闹钟层错误日志出口。 */
internal fun alarmLogError(message: String, tr: Throwable? = null) {
    Log.e(LOG_TAG, "[T10.5][alarm-native] $message", tr)
}

private const val LOG_TAG_BOOT = "T11"

/**
 * T11 开机重建的日志出口。
 *
 * - tag 用 `T11`，这样 `adb logcat -s T11` 可以只看重建过程；
 * - 消息里**保留 `alarm-native` 子串**，T10.5 既有的过滤命令
 *   （`logcat -d | grep -a alarm-native`）因此依然能一并抓到 T11 的行。
 *
 * **消息一律 ASCII**：T10.5 实测过，中文经 PowerShell 管道会变成乱码，
 * 所以这里只记 taskId / 时刻 / 计数，**不记任务标题**（标题是用户输入的中文）。
 */
internal fun alarmLogBoot(message: String) {
    Log.i(LOG_TAG_BOOT, "[T11][alarm-native][boot] $message")
}

private const val LOG_TAG_SCAN = "T19"

/**
 * T19 周期扫描（B 档兜底）的日志出口。
 *
 * - tag 用 `T19`：`adb logcat -s T19` 可以只看扫描过程；
 * - 消息里保留 `alarm-scan` 子串，既有的 `grep -a alarm` 类过滤依然能一并抓到；
 * - **消息一律 ASCII**（T10.5 实测过中文经 PowerShell 管道会乱码）。
 */
internal fun alarmLogScan(message: String) {
    Log.i(LOG_TAG_SCAN, "[T19][alarm-scan] $message")
}
