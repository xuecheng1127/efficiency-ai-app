import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/alarm_repository_impl.dart';
import '../domain/alarm_repository.dart';
import '../domain/scheduled_alarm.dart';

/// 闹钟仓库 Provider
final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  return AlarmRepositoryImpl(ref.watch(databaseProvider));
});

/// 全部闹钟记录（响应式，界面按 taskId 索引展示）。
final allAlarmsProvider = StreamProvider<List<ScheduledAlarm>>((ref) {
  return ref.watch(alarmRepositoryProvider).watchAll();
});

/// taskId → 闹钟 的索引（供任务列表显示小铃铛）
final alarmsByTaskProvider = Provider<Map<int, ScheduledAlarm>>((ref) {
  // Riverpod 3：AsyncValue.value 即「有值则有，否则 null」
  final alarms = ref.watch(allAlarmsProvider).value ?? const [];
  return {for (final a in alarms) a.taskId: a};
});
