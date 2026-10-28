import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/streak.dart';

/// 火花数据源：只读「已完成日期集合」，不做任何写入。
///
/// **不新增表**（评审边界）：火花完全由 `task_instances.status='done'` 的
/// `completed_at` 推导。新增一张 streak 表意味着两处真源，迟早对不上。
abstract interface class StreakRepository {
  /// 监听已完成任务的日期集合（本地日期，零点归一化）。
  ///
  /// 用 Stream 而不是 Future：用户完成任务 → UI 的火花数字当场 +1，
  /// 不需要退出页面再进来。
  Stream<Set<DateTime>> watchCompletedDays();
}

class StreakRepositoryImpl implements StreakRepository {
  StreakRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<Set<DateTime>> watchCompletedDays() {
    final completedAt = _db.taskInstances.completedAt;
    final query = _db.selectOnly(_db.taskInstances)
      ..addColumns([completedAt])
      // 只认「真的完成过」：todo / inProgress 没有 completed_at，
      // 被撤回完成（UNDO-COMPLETE）的实例 completed_at 已被清空，也不算。
      ..where(_db.taskInstances.status.equals('done') & completedAt.isNotNull())
      ..orderBy([OrderingTerm.asc(completedAt)]);

    return query.watch().map((rows) {
      final days = <DateTime>{};
      for (final row in rows) {
        final at = row.read(completedAt);
        if (at != null) days.add(streakDateOnly(at));
      }
      return days;
    });
  }
}
