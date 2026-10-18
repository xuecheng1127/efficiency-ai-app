package com.efficiency.app.efficiency_app.alarm

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/**
 * B 档兜底的周期 Worker（T19 R1）。
 *
 * 每个周期做一件事：**扫一遍「该响没响」并补一次**。它不持有任何状态
 * —— 状态就是 `scheduled_alarms`（真源）+ [AlarmFireMarkers]（处理痕迹），
 * 所以进程被杀、设备重启都不影响正确性。
 *
 * **日志是本次验收的主要证据**：每个周期打一行 `scan start` 与一行 `scan complete`，
 * 都带 `scanned` / `missed` / `compensated` 计数与时间戳，评审方可以用它数周期。
 *
 * 失败时返回 `Result.retry()`：WorkManager 会按退避策略重试（而不是静默丢掉一个周期）。
 */
class AlarmScanWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val ctx = applicationContext
        val now = System.currentTimeMillis()

        alarmLogScan(
            "scan start attempt=$runAttemptCount tier=${AlarmScheduler.tierNow(ctx).name} " +
                "canScheduleExactAlarms=${AlarmScheduler.canScheduleExactAlarms(ctx)} " +
                "intervalMin=${AlarmScanScheduler.INTERVAL_MINUTES} " +
                "lookbackMin=${MissedAlarmScanner.LOOKBACK_MILLIS / 60_000}",
        )

        return try {
            val outcome = MissedAlarmScanner.scan(ctx, now)
            val compensated = MissedAlarmScanner.compensate(ctx, outcome.missed)
            alarmLogScan(
                "scan complete scanned=${outcome.scanned} missed=${outcome.missed.size} " +
                    "compensated=$compensated (idempotent: handled occurrences are skipped)",
            )
            Result.success()
        } catch (e: Exception) {
            // 不吞异常：让 WorkManager 按退避重试，同时留下可 grep 的记录
            alarmLogError("scan failed; scheduling retry", e)
            Result.retry()
        }
    }
}
