package com.efficiency.app.alarm

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * T12：精确闹钟权限变化接收器
 *
 * 监听 ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED（仅在用户授予权限时发送），
 * 权限变化后全量重排闹钟（升级/降级档位）。
 *
 * 注意：撤销权限时系统不发此广播（且会杀掉应用），撤销路径由 app 回到前台时对比档位处理。
 */
class ExactAlarmPermissionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ExactAlarmPerm"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED) return

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val granted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            am.canScheduleExactAlarms()
        } else true

        Log.i(TAG, "permission state changed, exact=$granted, rebuilding all alarms")

        // 复用 BootReceiver 的重建逻辑
        BootReceiver.rebuildAlarms(context)
    }
}
