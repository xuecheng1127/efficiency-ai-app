import 'package:flutter/services.dart';

/// 闹钟调度通道：封装 Android AlarmManager，实现三档降级（见 ADR-003）。
///
/// **T10 起，本通道只负责「把调度意图交给原生」，不再承载参数。**
/// 闹钟的全部参数由 `scheduled_alarms` 表持久化，原生侧（含 T11 的开机重建）
/// 一律从表中读取，避免「参数只活在 Intent extra 里」的老问题。
///
/// 原生侧职责（后续任务实现）：
/// - 精确档：canScheduleExactAlarms() 为 true 时用 setExactAndAllowWhileIdle；
/// - 近似档：权限被拒时降级为 setWindow(60s) + 周期扫描兜底（T19）；
/// - 重启后由 BOOT_COMPLETED 触发 rescheduleAll 重建未来闹钟（T11）。
///
/// 注意：原生侧尚未接入（见 README TODO），调用会抛 MissingPluginException；
/// 调用方需自行降级处理，不得让持久化结果受影响。
class AlarmScheduler {
  static const MethodChannel _channel = MethodChannel('efficiency_app/alarm');

  /// 是否已授予精确闹钟权限（决定走 A 档还是 B 档）
  static Future<bool> canScheduleExactAlarms() async {
    return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ?? false;
  }

  /// 引导用户开启「闹钟和提醒」权限（跳转系统设置页）
  static Future<void> requestExactAlarmPermission() async {
    await _channel.invokeMethod('requestExactAlarmPermission');
  }

  /// 提交一次调度：原生侧据 taskId 回查 `scheduled_alarms` 取全部参数。
  static Future<void> schedule({
    required int taskId,
    required DateTime triggerAt,
    required bool enabled,
  }) async {
    await _channel.invokeMethod('schedule', {
      'taskId': taskId,
      'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      'enabled': enabled,
    });
  }

  /// 按任务取消闹钟。
  static Future<void> cancel(int taskId) async {
    await _channel.invokeMethod('cancel', {'taskId': taskId});
  }

  /// 重建所有未来闹钟（开机 / 权限恢复时调用，T11 / T12 使用）
  static Future<void> rescheduleAll() async {
    await _channel.invokeMethod('rescheduleAll');
  }
}
