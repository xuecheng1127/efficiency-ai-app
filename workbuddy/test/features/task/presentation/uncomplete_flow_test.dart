import 'dart:async';

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

/// UNDO-COMPLETE 回归（界面层）：长按 →「标记为未完成」→ 确认，以及完成后的撤销。
class _FakeRepo implements TaskRepository {
  final completed = <int>[];
  final uncompleted = <int>[];

  @override
  Future<void> completeInstance(int instanceId) async {
    completed.add(instanceId);
  }

  @override
  Future<void> uncompleteInstance(int instanceId) async {
    uncompleted.add(instanceId);
  }

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
  TaskInstance instance(TaskStatus status) => TaskInstance(
    id: 1,
    templateId: 1,
    occurrenceDate: DateTime(2026, 10, 18),
    titleSnapshot: '背单词',
    typeSnapshot: TaskType.study,
    status: status,
    accumulatedSeconds: status == TaskStatus.done ? 300 : 0,
  );

  Future<_FakeRepo> pumpPage(WidgetTester tester, TaskStatus status) async {
    final repo = _FakeRepo();
    final instances = StreamController<List<TaskInstance>>();
    addTearDown(instances.close);
    instances.add([instance(status)]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repo),
          todayInstancesProvider.overrideWith((ref) => instances.stream),
          allAlarmsProvider.overrideWith(
            (ref) => Stream.value(const <ScheduledAlarm>[]),
          ),
        ],
        child: const MaterialApp(home: TaskListPage()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('已完成：长按 →「标记为未完成」→ 确认，才真的撤回', (tester) async {
    final repo = await pumpPage(tester, TaskStatus.done);

    await tester.longPress(find.text('背单词'));
    await tester.pumpAndSettle();
    expect(find.text('标记为未完成'), findsOneWidget);

    await tester.tap(find.text('标记为未完成'));
    await tester.pumpAndSettle();

    // 确认框出现，且此时还没落库
    expect(find.text('要把「背单词」标记回未完成吗？'), findsOneWidget);
    expect(repo.uncompleted, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, '标记为未完成'));
    await tester.pumpAndSettle();
    expect(repo.uncompleted, [1]);
  });

  testWidgets('确认框点「取消」：什么都不做', (tester) async {
    final repo = await pumpPage(tester, TaskStatus.done);

    await tester.longPress(find.text('背单词'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标记为未完成'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(repo.uncompleted, isEmpty);
  });

  testWidgets('完成时给 5 秒「撤销」，点了就退回未完成', (tester) async {
    final repo = await pumpPage(tester, TaskStatus.todo);

    await tester.tap(find.byTooltip('标记完成'));
    await tester.pumpAndSettle();

    expect(repo.completed, [1]);
    expect(find.text('已完成'), findsWidgets);
    expect(find.text('撤销'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(repo.uncompleted, [1]);
  });

  testWidgets('「撤销」提示 5 秒后自动消失（不常驻）', (tester) async {
    await pumpPage(tester, TaskStatus.todo);

    await tester.tap(find.byTooltip('标记完成'));
    await tester.pumpAndSettle();
    expect(find.text('撤销'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('撤销'), findsNothing);
  });

  testWidgets('未完成的任务长按不弹菜单（不给多余入口）', (tester) async {
    await pumpPage(tester, TaskStatus.todo);

    await tester.longPress(find.text('背单词'));
    await tester.pumpAndSettle();

    expect(find.text('标记为未完成'), findsNothing);
  });
}
