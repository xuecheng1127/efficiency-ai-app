import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/task_repository_impl.dart';
import '../domain/task_enums.dart';
import '../domain/task_instance.dart';
import '../domain/task_repository.dart';

/// 任务仓库 Provider（T01：Drift 实现，依赖倒置经 Domain 接口）
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(AppDatabase.instance);
});

/// 今日任务列表 Provider（AsyncValue 统一异步状态）
///
/// 订阅数据库变化：新增/修改/完成任务时自动刷新列表。
final todayTasksProvider =
    StreamProvider<List<TaskWithOccurrence>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.watchTodayTasks();
});

/// 任务统计（供主页横幅展示）
final taskStatsProvider = Provider<TaskStats>((ref) {
  final tasks = ref.watch(todayTasksProvider);
  return tasks.when(
    data: (list) {
      var done = 0, inProgress = 0, totalSeconds = 0;
      for (final item in list) {
        final occ = item.occurrence;
        if (occ.status == TaskStatus.done) {
          done++;
          totalSeconds += occ.accumulatedSeconds;
        } else if (occ.status == TaskStatus.inProgress) {
          inProgress++;
        }
      }
      return TaskStats(
        total: list.length,
        done: done,
        inProgress: inProgress,
        totalSeconds: totalSeconds,
      );
    },
    loading: () => TaskStats.empty(),
    error: (_, __) => TaskStats.empty(),
  );
});

/// 任务统计值对象
class TaskStats {
  final int total;
  final int done;
  final int inProgress;
  final int totalSeconds;

  const TaskStats({
    required this.total,
    required this.done,
    required this.inProgress,
    required this.totalSeconds,
  });

  const TaskStats.empty()
      : total = 0,
        done = 0,
        inProgress = 0,
        totalSeconds = 0;

  /// 今日完成进度 0~1
  double get progress =>
      total == 0 ? 0 : done / total;

  /// 今日累计耗时格式化 mm:ss / hh:mm:ss
  String get formattedDuration {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// 供 UI 使用的实例快捷读取（字段名与新模型对齐）
extension TaskInstanceView on TaskInstance {
  /// 累计耗时秒数（兼容旧 durationSeconds 引用处）
  int get durationSeconds => accumulatedSeconds;
}
