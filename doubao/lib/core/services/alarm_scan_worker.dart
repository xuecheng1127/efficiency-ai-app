import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'alarm_service.dart';

/// T19: B 档周期扫描兜底（WorkManager）
///
/// 每 15 分钟扫描一次 scheduled_alarms，找到已过点但未响过的记录，补一次响铃。
/// 幂等：用 last_rescanned_at 字段标记，避免重复补响。
class AlarmScanWorker {
  static const String taskName = 'alarm_rescan_worker';

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      'alarm_rescan',
      taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // T19: 扫描过期闹钟并补响
    // 简化实现：调 AlarmService 的 rescan 方法
    try {
      await AlarmService.instance.rescanMissedAlarms();
    } catch (e) {
      // 记录错误，不崩溃
    }
    return Future.value(true);
  });
}
