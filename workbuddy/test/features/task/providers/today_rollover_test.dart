import 'dart:async';

import 'package:efficiency_app/core/time/day_tick.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_instance.dart';
import 'package:efficiency_app/features/task/domain/task_repository.dart';
import 'package:efficiency_app/features/task/providers/task_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// HARDENING A5：跨零点后「今日任务」必须换成新的一天。
///
/// 现场：日期是 build 那一刻的 `DateTime.now()`，应用开着过夜后任务页仍显示昨天的
/// 实例（实测 00:00:56 仍写着「10月28日·周三」）。现在日期来自 [dayTickProvider]，
/// 换日时先 backfill 新一天、再重新订阅。
class _RecordingRepo implements TaskRepository {
  final backfilled = <DateTime>[];
  final watched = <DateTime>[];

  @override
  Future<void> backfill(DateTime today) async => backfilled.add(today);

  @override
  Stream<List<TaskInstance>> watchTodayInstances(DateTime today) {
    watched.add(today);
    return Stream.value(const <TaskInstance>[]);
  }

  @override
  Future<void> completeInstance(int instanceId) async {}

  @override
  Future<void> uncompleteInstance(int instanceId) async {}

  @override
  Future<int> addTemplate({
    required TaskType type,
    required String title,
    required RepeatMode repeatMode,
    List<int> repeatDays = const [],
  }) async => 0;

  @override
  Future<void> startTimer(int instanceId) async {}

  @override
  Future<void> cancelTimer(int instanceId) async {}

  @override
  Future<void> deleteInstance(int instanceId) async {}

  @override
  Future<void> deleteTemplate(int templateId, {DateTime? now}) async {}
}

void main() {
  test('节拍换日：先用旧日期 backfill + 订阅，跨零点后自动换成新日期', () async {
    final repo = _RecordingRepo();
    final ticks = StreamController<DateTime>();
    addTearDown(ticks.close);

    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        dayTickProvider.overrideWith((ref) => ticks.stream),
      ],
    );
    addTearDown(container.dispose);

    // 订阅才会真正建流（StreamProvider 是惰性的）
    final sub = container.listen(todayInstancesProvider, (_, __) {});
    addTearDown(sub.close);

    // 用远离「真实今天」的日期：首帧的兜底值（真实今天）才不会被误认成 day1/day2。
    final day1 = DateTime(2030, 1, 1);
    final day2 = DateTime(2030, 1, 2);

    ticks.add(day1);
    await pumpEventQueue();
    // 首帧可能先用「真实今天」顶一次（节拍还没到），所以看最后一次。
    expect(repo.backfilled.last, day1, reason: '先补齐当日实例');
    expect(repo.watched.last, day1, reason: '再按同一天订阅');

    // 跨零点
    ticks.add(day2);
    await pumpEventQueue();

    expect(repo.backfilled.last, day2, reason: '新的一天也要补实例');
    expect(repo.watched.last, day2, reason: '必须重新按新日期订阅');
    expect(repo.watched.where((d) => d == day2).length, 1);
  });
}
