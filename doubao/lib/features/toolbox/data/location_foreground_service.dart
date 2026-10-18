import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 途径提醒后台监控开关
///
/// V1：仅持久化开关状态。真正的前台服务位置轮询需要在后台 isolate 里
/// 重新初始化 location 插件 + Drift，复杂度高，留作 V2。
/// 当前开关打开时，前台 LocationReminderMonitor 会保持运行；
/// app 切到后台后由系统限制可能被杀，不保证持续监控。
final locationBgEnabledProvider =
    StateNotifierProvider<LocationBgNotifier, bool>((ref) => LocationBgNotifier());

class LocationBgNotifier extends StateNotifier<bool> {
  LocationBgNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = p.getBool('location_bg_enabled') ?? false;
  }

  Future<void> set(bool v) async {
    state = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('location_bg_enabled', v);
  }
}
