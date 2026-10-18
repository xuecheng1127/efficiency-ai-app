package com.efficiency.app.efficiency_app.alarm

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * 周期扫描的登记处（T19 R2）。
 *
 * ## 间隔为什么选 15 分钟（漏响窗口 vs 耗电）
 *
 * - **平台下限就是 15 分钟**（`PeriodicWorkRequest.MIN_PERIODIC_INTERVAL_MILLIS`），
 *   选它 = 把「B 档漏响后的最坏延迟」压到最小，这正是 T19 的目的（B 档实测会晚 2～10 分钟）。
 * - **耗电代价可忽略**：一次扫描只做「打开一个只读 sqlite、查一张几行的表、可能发一条通知」，
 *   没有网络、没有 wakelock、没有循环等待；WorkManager 还会把多个任务合批唤醒。
 * - **不选更长的间隔**：30/60 分钟会让「晚 10 分钟才响」变成「晚 30～60 分钟才响」，
 *   而闹钟的价值就建立在准时上。
 * - **不放约束**（`Constraints` 全空）：加了「充电时/有网时」之类的约束，等于让兜底在
 *   最需要它的时候（省电模式、无网）不跑。Doze 下 WorkManager 会在维护窗口执行，
 *   实测间隔见报告。
 *
 * ## 幂等登记
 *
 * 用 `enqueueUniquePeriodicWork(..., ExistingPeriodicWorkPolicy.KEEP, ...)`：
 * 应用每次启动都会调用 [ensureScheduled]，**KEEP 保证不会把已有周期重置**，
 * 所以「启动一次就重排一次」不会导致周期永远跑不到。
 */
object AlarmScanScheduler {

    /** 唯一工作名：改这个名字会另起一条周期，历史调度不会自动迁移。 */
    const val WORK_NAME = "alarm_missed_scan_b_fallback"

    /** T19 R2：15 分钟（平台周期任务最小值）。 */
    const val INTERVAL_MINUTES = 15L

    /** WorkManager 查询用的标签。 */
    const val TAG = "alarm_scan"

    /**
     * 登记周期扫描（幂等，可在每次应用启动时调用）。
     *
     * WorkManager 的周期任务**由 WorkManager 自己持久化**，设备重启后会自动恢复，
     * 所以只需要应用启动时登记一次即可，不必依赖自己的开机广播（T11 那条线因此不用动）。
     */
    fun ensureScheduled(context: Context) {
        try {
            val request = PeriodicWorkRequestBuilder<AlarmScanWorker>(
                INTERVAL_MINUTES,
                TimeUnit.MINUTES,
            ).addTag(TAG).build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
            alarmLogScan(
                "periodic work ensured: name=$WORK_NAME intervalMin=$INTERVAL_MINUTES " +
                    "policy=KEEP (platform minimum is 15min)",
            )
        } catch (e: Exception) {
            // 登记失败不应影响闹钟主链路：如实记录，等下次启动再试
            alarmLogError("ensureScheduled failed", e)
        }
    }
}
