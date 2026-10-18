package com.efficiency.app.alarm

import android.annotation.SuppressLint
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.widget.Toast
import com.efficiency.app.R
import java.util.Calendar
import java.util.Locale

/**
 * 闹钟全屏响铃页（T13b：只做 UI，不再持有 MediaPlayer）
 *
 * T13b 变更：
 * - MediaPlayer 已移至 AlarmService，本页被销毁不影响响铃
 * - 关闭/贪睡动作改为调用 AlarmService.stop()，由服务停铃 + 撤通知
 * - 保留 T14 来源校验、T15-2 息屏即停
 */
@SuppressLint("ClickableViewAccessibility")
class AlarmFullScreenActivity : Activity() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var dismissByUser = false
    private var gestureDetector: GestureDetector? = null

    /** 息屏广播接收器：用户按电源键熄屏即关闭闹钟 */
    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                dismissAlarm()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // T14：来源校验——只接受自己的 ACTION_ALARM，拒绝第三方拉起
        if (intent.action != AlarmReceiver.ACTION_ALARM) {
            finish()
            return
        }
        // 全屏 + 屏幕常亮
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_alarm_full_screen)

        // T15-2：动态注册息屏广播——用户按电源键熄屏即关闭闹钟
        registerReceiver(screenOffReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))

        bindUi()
        // T13b：不再 startRingtone()，响铃由 AlarmService 负责
    }

    private fun bindUi() {
        val title = intent.getStringExtra(AlarmScheduler.EXTRA_TITLE) ?: "任务提醒"
        val isSnooze = intent.getBooleanExtra(AlarmScheduler.EXTRA_IS_SNOOZE, false)
        val snoozeCount = intent.getIntExtra(AlarmScheduler.EXTRA_SNOOZE_COUNT, 0)
        val snoozeEnabled = intent.getBooleanExtra(AlarmScheduler.EXTRA_SNOOZE_ENABLED, true)
        val taskId = intent.getIntExtra(AlarmScheduler.EXTRA_TASK_ID, -1)

        findViewById<TextView>(R.id.tv_alarm_title).text = title
        val tvTime = findViewById<TextView>(R.id.tv_alarm_time)
        val tvHint = findViewById<TextView>(R.id.tv_alarm_hint)
        tvHint.text = if (isSnooze) "贪睡中 · 第 $snoozeCount 次响铃" else "下滑关闭 · 息屏即停"

        // 当前时间实时刷新（秒级）
        mainHandler.post(object : Runnable {
            override fun run() {
                tvTime.text = timeNow()
                mainHandler.postDelayed(this, 1000)
            }
        })

        // 关闭按钮
        findViewById<View>(R.id.btn_alarm_dismiss).setOnClickListener { dismissAlarm() }

        // 贪睡按钮：snoozeCount >= 3 或全局关闭贪睡时隐藏
        val btnSnooze = findViewById<View>(R.id.btn_alarm_snooze)
        if (!snoozeEnabled || snoozeCount >= 3 || taskId < 0) {
            btnSnooze.visibility = View.GONE
        } else {
            btnSnooze.setOnClickListener {
                snoozeAndDismiss(taskId, snoozeCount)
            }
        }

        // 下滑手势关闭
        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onFling(e1: MotionEvent?, e2: MotionEvent, vx: Float, vy: Float): Boolean {
                val dy = e2.y - (e1?.y ?: e2.y)
                if (dy > 180 && Math.abs(dy) > Math.abs(vx)) {
                    dismissAlarm()
                    return true
                }
                return false
            }
        })
        val root = findViewById<View>(R.id.alarm_root)
        root.setOnTouchListener { _, event ->
            gestureDetector?.onTouchEvent(event) ?: false
        }
    }

    /** 贪睡：通知服务重排贪睡闹钟后关闭 */
    private fun snoozeAndDismiss(taskId: Int, snoozeCount: Int) {
        // T13b：直接启动服务的 SNOOZE action，由服务处理停铃 + 重排贪睡
        AlarmService.stop(this, taskId, AlarmService.ACTION_SNOOZE)
        Toast.makeText(this, "已贪睡", Toast.LENGTH_SHORT).show()
        dismissAlarm()
    }

    /** 关闭闹钟：通知服务停铃 + 撤通知，然后结束页面 */
    private fun dismissAlarm() {
        if (dismissByUser) return
        dismissByUser = true
        val taskId = intent.getIntExtra(AlarmScheduler.EXTRA_TASK_ID, -1)
        // T13b：通知服务停铃 + 撤通知
        AlarmService.stop(this, taskId, AlarmService.ACTION_DISMISS)
        mainHandler.removeCallbacksAndMessages(null)
        finishAndRemoveTask()
    }

    override fun onDestroy() {
        try { unregisterReceiver(screenOffReceiver) } catch (_: Exception) {}
        // T13b：不再 stopRingtone()，响铃由服务持有
        mainHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun timeNow(): String {
        val c = Calendar.getInstance()
        return String.format(
            Locale.getDefault(), "%02d:%02d:%02d",
            c.get(Calendar.HOUR_OF_DAY),
            c.get(Calendar.MINUTE),
            c.get(Calendar.SECOND),
        )
    }
}
