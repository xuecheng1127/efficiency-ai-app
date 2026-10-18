import 'package:flutter/services.dart';

/// 步数数据源抽象：Android 统一走 Health Connect（见 ADR-004）。
abstract interface class StepDataSource {
  /// 获取今日步数
  Future<int> getTodaySteps();
}

/// Health Connect 实现：通过 MethodChannel 调用原生 Health Connect API。
///
/// 原生侧职责：
/// - AndroidManifest 声明 Health Connect READ 权限；
/// - Android 9–13 需引导用户安装 Health Connect 应用；
/// - 上架需提供隐私政策链接（健康数据属敏感权限）。
class HealthConnectStepSource implements StepDataSource {
  static const MethodChannel _channel = MethodChannel('efficiency_app/health');

  @override
  Future<int> getTodaySteps() async {
    return await _channel.invokeMethod<int>('getTodaySteps') ?? 0;
  }
}
