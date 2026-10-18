package com.efficiency.app.efficiency_app.alarm

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.efficiency.app.efficiency_app.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 全屏响铃页 —— **T13b 之后它只做 UI**。
 *
 * 由 `Notification.setFullScreenIntent` 交给系统拉起（**本页绝不会被 `startActivity` 拉起**）。
 *
 * ## 响铃不在这里（T13b 解耦）
 *
 * 之前 `MediaPlayer` 挂在本页上、`onDestroy` 里 `stopRing()`。真机实测（2026-10-16 23:35）
 * 本页在 `onResume` 后约 **50ms** 就被 ROM 销毁 —— **铃只响了 211 毫秒**。
 * 现在响铃归 [AlarmService]，本页被销毁**不影响响铃**：
 * 三个按钮/事件都只是「把用户的意图转发给服务」。
 *
 * ## 关闭方式（对应 PRD「闹钟全屏页面支持快速关闭」）
 *
 * - 「关闭」按钮 → 转发 `ACTION_DISMISS`
 * - 「贪睡」按钮 → 转发 `ACTION_SNOOZE`
 * - **息屏即关闭**：动态注册 `ACTION_SCREEN_OFF`，屏幕一黑就**转发关闭**。
 *   这里**故意不使用 `KEYCODE_POWER`** —— 电源键在系统分发前就被消费，应用收不到；
 *   即便收到，`return true` 还会让电源键无法熄屏，等于废掉用户的电源键（修复清单 T15 定案）。
 *
 * ## T14 来源校验（`exported="true"` 的代价兜底）
 *
 * 本页在 manifest 里是 `exported="true"`（锁屏场景由 SystemUI 代启所必需），
 * 因此 `onCreate` / `onNewIntent` 必须校验 intent 的 action 是否严格等于本应用自己的
 * [AlarmContract.ACTION_ALARM]，否则立刻 `finish()`。
 */
class AlarmFullScreenActivity : Activity() {

    private var taskId: Int = -1
    private var record: ScheduledAlarmRecord? = null
    private var screenOffReceiver: BroadcastReceiver? = null

    private val tvTime: TextView get() = findViewById(R.id.tv_alarm_time)
    private val tvTitle: TextView get() = findViewById(R.id.tv_alarm_title)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        taskId = intent.getIntExtra(AlarmContract.EXTRA_TASK_ID, -1)

        // ---------------- T14 来源校验（exported=true 之后的第一道闸） ----------------
        // 本页只接受**本应用自己的闹钟 Intent**（action 严格等于 ACTION_ALARM）。
        // 其它任何来源 —— 包括第三方应用显式 startActivity —— 一律拒绝并立刻收尾。
        //
        // 位置：放在 super.onCreate **之后**、一切副作用**之前**。
        //  - 之所以不放在 super.onCreate 之前：先 finish() 再 super.onCreate 是已知会踩
        //    ActivityThread 主题/窗口初始化的写法，故意避开；
        //  - 之所以必须在这里：此处还没 setContentView、没注册 receiver、没播铃、
        //    没申请任何东西，拒绝的代价为零。
        if (!isFromOwnAlarm(intent)) {
            alarmLog(
                "rejected(taskId=$taskId) unexpected intent: " +
                    "action=${intent?.action} launchedFrom=${launchedFromPackageOrNull()} -> finish()",
            )
            finish()
            return
        }

        // 锁屏上直接显示并点亮屏幕（API 27+ 用新 API，低版本用 window flag）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContentView(R.layout.activity_alarm_full_screen)
        setFinishOnTouchOutside(false)

        // 参数一律来自表（标题 / 时点），不做任何 Intent extra 传递
        record = if (taskId > 0) AlarmStore.loadByTask(this, taskId) else null
        bindViews()

        // T13b：这里只转发意图，**不碰 MediaPlayer**
        findViewById<Button>(R.id.btn_alarm_dismiss).setOnClickListener {
            alarmLog("ui dismissed(taskId=$taskId) source=fullscreen-button -> forward to AlarmService")
            AlarmService.sendControl(this, AlarmContract.ACTION_DISMISS, taskId)
            finish()
        }
        findViewById<Button>(R.id.btn_alarm_snooze).setOnClickListener {
            alarmLog("ui snoozed(taskId=$taskId) source=fullscreen-button -> forward to AlarmService")
            AlarmService.sendControl(this, AlarmContract.ACTION_SNOOZE, taskId)
            finish()
        }

        alarmLog(
            "fullscreen shown(taskId=$taskId) source=setFullScreenIntent lockScreen=${isLocked()} " +
                "uiOnly=true ringOwner=AlarmService " +
                "record=${record?.let { "table{title=${it.taskTitle}, time=${it.timeLabel()}, volume=${it.volume}, snoozeMinutes=${it.snoozeMinutes}}" } ?: "null"}",
        )
    }

    /**
     * T14：`launchMode="singleInstance"` 下，重复的合法触发会复用本实例并走这里。
     *
     * 与 `onCreate` 走**同一道**校验：非法来源同样立刻 `finish()`。
     * 合法的重复触发只刷新 UI（响铃由服务持有，不在这里重复起播）。
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (!isFromOwnAlarm(intent)) {
            alarmLog(
                "rejected(taskId=$taskId) unexpected onNewIntent: " +
                    "action=${intent.action} launchedFrom=${launchedFromPackageOrNull()} -> finish()",
            )
            finish()
            return
        }
        setIntent(intent)
        taskId = intent.getIntExtra(AlarmContract.EXTRA_TASK_ID, taskId)
        record = if (taskId > 0) AlarmStore.loadByTask(this, taskId) else null
        bindViews()
        alarmLog("newIntent accepted(taskId=$taskId) -> reuse current page (ring untouched, owner=AlarmService)")
    }

    // ------------------------------------------------------------ T14 来源校验

    /** 本页只认本应用自己的闹钟 action（**严格相等**的白名单语义，不是"action 非空即可"）。 */
    private fun isFromOwnAlarm(intent: Intent?): Boolean =
        intent?.action == AlarmContract.ACTION_ALARM

    /**
     * 「谁拉起了本页」——**只记日志，不做闸门。**
     *
     * `getLaunchedFromPackage()` 是 API 34+ 才有的。本轮无设备，无法实测 SystemUI 代启时
     * 这个值到底是本应用包名还是 `com.android.systemui`；拿一个**未经验证**的值去做硬校验，
     * 有可能把正要修的那条路径重新挡死。等真机复验拿到实测值后，再决定是否把它收紧成闸门。
     */
    private fun launchedFromPackageOrNull(): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try {
                launchedFromPackage
            } catch (_: Exception) {
                null
            }
        } else {
            null
        }

    // ------------------------------------------------------------ 生命周期观测（T14 补）

    // 为什么补这几行：9b 真机实测时，全屏页"系统日志里有 Displayed、屏幕上却没有"，
    // 而当时代码在 onPause/onStop/onDestroy 都不打日志，无法区分
    // 「被锁屏压住（Activity 还活着）」与「已被销毁（onDestroy 会 stopRing，
    // 但**不撤通知**，所以'通知还在'并不能反推页面还活着）」。
    // 这四个回调一起，真机复验时就能拼出完整时间线。
    //
    // T13b 之后它们的语义变得更重要：**这些日志现在只描述页面，不再描述响铃** ——
    // 看到 onDestroy 不等于铃停了（铃在 AlarmService 里），要停铃的证据看服务侧日志。

    override fun onResume() {
        alarmLog("lifecycle onResume  taskId=$taskId keyguard=${isLocked()}")
        super.onResume()
    }

    override fun onPause() {
        alarmLog("lifecycle onPause   taskId=$taskId keyguard=${isLocked()}")
        super.onPause()
    }

    // ------------------------------------------------------------ 息屏即收尾（转发）

    override fun onStart() {
        super.onStart()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_SCREEN_OFF) {
                    // 息屏 = 用户关掉闹钟（替代不可靠的电源键拦截）。
                    // T13b：这里只把「关闭」意图转发给服务 —— 页面被销毁不会影响响铃，
                    // 但**用户按电源键**这个明确意图仍然要停铃。
                    alarmLog("ACTION_SCREEN_OFF received -> forward dismiss(taskId=$taskId) to AlarmService")
                    AlarmService.sendControl(context, AlarmContract.ACTION_DISMISS, taskId)
                    finish()
                }
            }
        }
        screenOffReceiver = receiver
        ContextCompat.registerReceiver(
            this,
            receiver,
            IntentFilter(Intent.ACTION_SCREEN_OFF),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onStop() {
        alarmLog("lifecycle onStop    taskId=$taskId keyguard=${isLocked()}")
        screenOffReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        screenOffReceiver = null
        super.onStop()
    }

    override fun onDestroy() {
        alarmLog("lifecycle onDestroy taskId=$taskId keyguard=${isLocked()} (ring owner=AlarmService -> ring NOT stopped here)")
        super.onDestroy()
    }

    private fun bindViews() {
        val time = record?.timeLabel()
            ?: SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        tvTime.text = time
        tvTitle.text = record?.taskTitle ?: "任务提醒"
        findViewById<Button>(R.id.btn_alarm_snooze).isEnabled = record?.snoozeEnabled ?: false
    }

    private fun isLocked(): Boolean =
        getSystemService(KeyguardManager::class.java)?.isKeyguardLocked == true

    companion object {
        /**
         * 构造本页的 Intent（供 `setFullScreenIntent` 的 PendingIntent 使用）。
         *
         * **action 必须是 [AlarmContract.ACTION_ALARM]** —— T14 的来源校验就认它；
         * 换掉这个 action 会让全屏页被自己的校验挡在门外。
         *
         * T13b 之后本页不再持有响铃，所以这里**没有** `AUTO_STOP_MILLIS` 之类的响铃参数
         * （那些已经全部归 `AlarmService` / `AlarmContract`）。
         */
        fun newIntent(context: Context, taskId: Int): Intent =
            Intent(context, AlarmFullScreenActivity::class.java).apply {
                action = AlarmContract.ACTION_ALARM
                putExtra(AlarmContract.EXTRA_TASK_ID, taskId)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
                )
            }
    }
}
