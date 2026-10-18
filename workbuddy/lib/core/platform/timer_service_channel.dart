import 'package:flutter/services.dart';

/// 前台服务计时通道：封装 flutter_foreground_task，退出应用不中断（见 ADR-006）。
///
/// 计时状态以「持久化的 startedAt」为唯一真源，进程被杀后据此重算，
/// 禁止依赖内存 Timer 累计。
class TimerService {
  static const MethodChannel _channel = MethodChannel('efficiency_app/timer');

  /// 开始计时（传入任务 id 与开始时间）
  static Future<void> start({
    required int taskId,
    required DateTime startedAt,
  }) async {
    await _channel.invokeMethod('start', {
      'taskId': taskId,
      'startedAtMillis': startedAt.millisecondsSinceEpoch,
    });
  }

  /// 暂停计时
  static Future<void> pause() => _channel.invokeMethod('pause');

  /// 停止计时
  static Future<void> stop() => _channel.invokeMethod('stop');

  /// 当前已计时秒数
  static Future<int> elapsedSeconds() async {
    return await _channel.invokeMethod<int>('elapsedSeconds') ?? 0;
  }
}
