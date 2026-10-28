import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/time/day_tick.dart';
import '../../alarm/providers/alarm_providers.dart';
import '../application/delete_task.dart';
import '../data/task_repository_impl.dart';
import '../domain/task_instance.dart';
import '../domain/task_repository.dart';

/// 任务仓库 Provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(databaseProvider));
});

/// 删除任务编排（撤闹钟 + 归档模板 + 软删实例），见 [DeleteTask]。
final deleteTaskProvider = Provider<DeleteTask>((ref) {
  return DeleteTask(
    ref.watch(taskRepositoryProvider),
    ref.watch(alarmRepositoryProvider),
  );
});

/// 今日实例列表 Provider（响应式：数据库变化自动刷新 UI）。
///
/// 消费方通过 [AsyncValue] 处理 loading / data / error 三态。
///
/// **跨零点（HARDENING A5）**：日期来自 [dayTickProvider]，不再是「build 那一刻的
/// `DateTime.now()`」。否则应用开着过夜，任务页会一直显示昨天的实例 —— 用户点完成
/// 写的是昨天的记录，第二天的重复任务也不会补建。
/// 换日时先 `backfill`（幂等）再订阅，新一天的实例当场补齐。
final todayInstancesProvider = StreamProvider<List<TaskInstance>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  // 节拍还没吐出第一帧时（一个 microtask 的空窗）先按「今天零点」顶上，
  // backfill 幂等，多跑一次没有副作用。
  final day = ref.watch(dayTickProvider).value ?? dayOnly(DateTime.now());

  return Stream.fromFuture(
    repo.backfill(day),
  ).asyncExpand((_) => repo.watchTodayInstances(day));
});
