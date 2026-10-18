import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
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

/// 前台轮询器：**第一次被读取时启动**（App 根部的监听组件会读它）。
///
/// 用 Provider 而不是在 main 里手动 new：这样它在需要时才创建，
/// 也能跟着 ProviderScope 一起销毁（`onDispose`），不会泄漏 Timer。
final locationWatcherProvider = Provider<LocationWatcher>((ref) {
  final watcher = LocationWatcher(ref.watch(locationRepositoryProvider));
  unawaitedStart(watcher);
  ref.onDispose(watcher.dispose);
  return watcher;
});

/// 小工具：避免在 Provider 里写 `unawaited` 需要额外 import。
void unawaitedStart(LocationWatcher watcher) {
  // ignore: discarded_futures
  watcher.start();
}
