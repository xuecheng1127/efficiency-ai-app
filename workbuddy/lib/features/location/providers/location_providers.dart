import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../application/location_monitor.dart';
import '../application/location_watcher.dart';
import '../data/location_repository_impl.dart';
import '../domain/location_reminder.dart';
import '../domain/location_repository.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(ref.watch(databaseProvider));
});

final locationRemindersProvider = StreamProvider<List<LocationReminder>>((ref) {
  return ref.watch(locationRepositoryProvider).watchAll();
});

/// 前台轮询器（没有前台服务时的兜底）。
///
/// **不再在被读取时自动 start**：R4 起由 [locationMonitorProvider] 统一决定
/// 「谁在跑」—— 服务能起就停掉它，否则再拉起它。两个都跑会让同一地点
/// 收到两条通知（服务一条、App 内定时器一条），这是实际发生过的问题。
final locationWatcherProvider = Provider<LocationWatcher>((ref) {
  final watcher = LocationWatcher(ref.watch(locationRepositoryProvider));
  ref.onDispose(watcher.dispose);
  return watcher;
});

/// 途径提醒的监测总开关：前台服务与前台轮询二选一，并负责把后台状态补回库。
final locationMonitorProvider = Provider<LocationMonitor>((ref) {
  final monitor = LocationMonitor(
    ref.watch(locationRepositoryProvider),
    ref.watch(locationWatcherProvider),
  );
  ref.onDispose(monitor.dispose);
  return monitor;
});
