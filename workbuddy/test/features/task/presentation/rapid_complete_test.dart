import 'package:efficiency_app/features/alarm/domain/scheduled_alarm.dart';
import 'package:efficiency_app/features/alarm/providers/alarm_providers.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_instance.dart';
import 'package:efficiency_app/features/task/domain/task_repository.dart';
import 'package:efficiency_app/features/task/presentation/task_list_page.dart';
import 'package:efficiency_app/features/task/providers/task_providers.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// HARDENING A3 · 连点「完成」的回归。
///
/// 现场：完成的条目会「沉底」（`watchTodayInstances` 按 done 排序），
/// 一次点击成功后列表会在手指下面重排 —— 同一个坐标的第二次点击落到**另一条**
/// 任务上，实测 10 连点把 3 条任务全标成了完成。
/// 现在 `_complete` 有 400ms 去抖窗口：窗口内的重复点击直接忽略。
class _FakeRepo implements TaskRepository {
  final completed = <int>[];

  @override
  Future<void> completeInstance(int instanceId) async => completed.add(instanceId);

  @override
  Future<void> uncompleteInstance(int instanceId) async {}

  @override
  Stream<List<TaskInstance>> watchTodayInstances(DateTime today) =>
      Stream.value(const []);

  @override
  Future<int> addTemplate({
    required TaskType type,
    required String title,
    required RepeatMode repeatMode,
    List<int> repeatDays = const [],
  }) async => 0;

  @override
  Future<void> backfill(DateTime today) async {}

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
  TaskInstance todo(int id, String title) => TaskInstance(
    id: id,
    templateId: id,
    occurrenceDate: DateTime(2026, 10, 29),
    titleSnapshot: title,
    typeSnapshot: TaskType.study,
    status: TaskStatus.todo,
    accumulatedSeconds: 0,
  );

  /// 页面用注入时钟：去抖窗口按「假时间」推进，测试才不被真实时钟卡住。
  Future<_FakeRepo> pumpPage(
    WidgetTester tester, {
    required ValueNotifier<DateTime> clock,
  }) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repo),
          todayInstancesProvider.overrideWith(
            (ref) => Stream.value([todo(1, '背单词'), todo(2, '跑步')]),
          ),
          allAlarmsProvider.overrideWith(
            (ref) => Stream.value(const <ScheduledAlarm>[]),
          ),
        ],
        child: MaterialApp(home: TaskListPage(clock: () => clock.value)),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('连点完成 10 次：只会落库 1 条（去抖窗口内忽略）', (tester) async {
    final clock = ValueNotifier(DateTime(2026, 10, 29, 9));
    final repo = await pumpPage(tester, clock: clock);

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip('标记完成').first);
      await tester.pump(); // 不推进时间 → 全部落在 400ms 窗口内
    }
    await tester.pumpAndSettle();

    expect(repo.completed, [1], reason: '10 次点击只能完成一条');
  });

  testWidgets('隔开窗口后再点：能正常完成下一条（不是永久锁死）', (tester) async {
    final clock = ValueNotifier(DateTime(2026, 10, 29, 9));
    final repo = await pumpPage(tester, clock: clock);

    await tester.tap(find.byTooltip('标记完成').first);
    await tester.pump();

    // 窗口内：忽略
    await tester.tap(find.byTooltip('标记完成').first);
    await tester.pump();
    expect(repo.completed, [1]);

    // 越过 400ms：放行
    clock.value = clock.value.add(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('标记完成').first);
    await tester.pumpAndSettle();

    expect(repo.completed.length, 2);
  });
}
