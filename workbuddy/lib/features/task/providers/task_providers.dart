import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
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
final todayInstancesProvider = StreamProvider<List<TaskInstance>>((ref) {
  return ref.watch(taskRepositoryProvider).watchTodayInstances(DateTime.now());
});
