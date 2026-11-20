import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../task/providers/task_providers.dart';
import '../data/today_widget_sync.dart';

/// 小组件同步器（复用任务仓库那份数据库连接）。
final todayWidgetSyncProvider = Provider<TodayWidgetSync>((ref) {
  return TodayWidgetSync(ref.watch(taskRepositoryProvider));
});
