import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../task/providers/task_providers.dart';

/// 火花系统：连续完成 ≥1 个任务的天数
class StreakState {
  final int current;
  final int longest;
  final DateTime? lastCompletedDate;
  const StreakState({
    this.current = 0,
    this.longest = 0,
    this.lastCompletedDate,
  });
}

final streakProvider = FutureProvider<StreakState>((ref) async {
  // 监听今日任务变化，任务完成时重算
  ref.watch(todayTasksProvider);
  final db = AppDatabase.instance;

  // 查所有完成实例的日期（归一化）
  final query = db.select(db.taskInstances)
    ..where((t) => t.status.equals('done') & t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.occurrenceDate)]);
  final rows = await query.get();
  final doneDates = rows
      .map((r) => DateTime(
          r.occurrenceDate.year, r.occurrenceDate.month, r.occurrenceDate.day))
      .toSet();

  if (doneDates.isEmpty) return const StreakState();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  // 当前火花：从今天往回数，每天都有 done 就 +1
  // 今天还没完成不算断（早上没做不扣）
  var current = 0;
  var cursor = doneDates.contains(today) ? today : yesterday;
  while (doneDates.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  // 最长火花：遍历所有日期
  final sorted = doneDates.toList()..sort();
  var longest = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }
  if (sorted.length == 1) longest = 1;

  return StreakState(
    current: current,
    longest: longest,
    lastCompletedDate: doneDates.isEmpty ? null : doneDates.first,
  );
});
