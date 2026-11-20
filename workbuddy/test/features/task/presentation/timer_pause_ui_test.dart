import 'dart:async';

import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_instance.dart';
import 'package:efficiency_app/features/task/presentation/widgets/task_tile.dart';
import 'package:efficiency_app/features/task/providers/task_ticker_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PHONE-FIX-1 · 计时暂停（界面层）。
///
/// 三件事必须在界面上成立：
/// 1. 计时中有「暂停」、已暂停有「继续」，两者都有「取消计时」；
/// 2. 暂停后秒数**停住**（不再订阅秒级时钟，数字冻在暂停那一刻）；
/// 3. 暂停/计时中的整行点击不再偷偷取消计时。
void main() {
  final startedAt = DateTime(2026, 10, 29, 10, 0, 0);

  TaskInstance item({
    required TaskStatus status,
    DateTime? start,
    int accumulated = 0,
  }) {
    return TaskInstance(
      id: 1,
      templateId: 1,
      occurrenceDate: DateTime(2026, 10, 29),
      titleSnapshot: '背单词',
      typeSnapshot: TaskType.study,
      status: status,
      startedAt: start,
      accumulatedSeconds: accumulated,
    );
  }

  Widget harness(
    TaskInstance instance,
    Stream<DateTime> clock, {
    VoidCallback? onToggle,
    VoidCallback? onPause,
    VoidCallback? onResume,
    VoidCallback? onCancel,
  }) {
    return ProviderScope(
      overrides: [taskTickerProvider.overrideWith((ref) => clock)],
      child: MaterialApp(
        home: Scaffold(
          body: TaskTile(
            instance: instance,
            onToggle: onToggle ?? () {},
            onComplete: () {},
            onDelete: () {},
            onAlarm: () {},
            onPause: onPause,
            onResume: onResume,
            onCancelTimer: onCancel,
          ),
        ),
      ),
    );
  }

  testWidgets('计时中：有「暂停」和「取消计时」，没有「继续」', (tester) async {
    final clock = StreamController<DateTime>();
    addTearDown(() => unawaited(clock.close()));

    await tester.pumpWidget(
      harness(
        item(status: TaskStatus.inProgress, start: startedAt),
        clock.stream,
      ),
    );

    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('取消计时'), findsOneWidget);
    expect(find.text('继续'), findsNothing);
  });

  testWidgets('点「暂停」触发回调；点整行不会偷偷取消计时', (tester) async {
    var toggled = 0;
    var paused = 0;
    final clock = StreamController<DateTime>();
    addTearDown(() => unawaited(clock.close()));

    await tester.pumpWidget(
      harness(
        item(status: TaskStatus.inProgress, start: startedAt),
        clock.stream,
        onToggle: () => toggled++,
        onPause: () => paused++,
        onCancel: () {},
      ),
    );

    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(paused, 1);

    // 点标题（卡体）——旧版这里是「取消计时」，现在必须什么都不发生
    await tester.tap(find.text('背单词'));
    await tester.pump();
    expect(toggled, 0, reason: '计时中整行不可点：不能让一次误触把这一轮时间清零');
  });

  testWidgets('已暂停：显示「继续」+「已暂停」，秒数冻住不动', (tester) async {
    var resumed = 0;
    final clock = StreamController<DateTime>();
    addTearDown(() => unawaited(clock.close()));

    await tester.pumpWidget(
      harness(
        item(status: TaskStatus.inProgress, accumulated: 30),
        clock.stream,
        onResume: () => resumed++,
      ),
    );

    expect(find.text('继续'), findsOneWidget);
    expect(find.text('暂停'), findsNothing);
    expect(find.text('取消计时'), findsOneWidget);
    expect(find.textContaining('已暂停 · 已计时 00:00:30'), findsOneWidget);

    // 暂停态压根不订阅秒级时钟 → 每秒重建这件事根本不会发生
    expect(clock.hasListener, isFalse, reason: '暂停后必须停止订阅，否则每秒白重建');

    // 即便把时钟往前推，数字也不能变
    clock.add(startedAt.add(const Duration(minutes: 5)));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('已暂停 · 已计时 00:00:30'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(resumed, 1);
  });

  testWidgets('计时中：订阅时钟，秒数真的在跳', (tester) async {
    final clock = StreamController<DateTime>();
    addTearDown(() => unawaited(clock.close()));

    await tester.pumpWidget(
      harness(
        item(status: TaskStatus.inProgress, start: startedAt),
        clock.stream,
      ),
    );

    expect(clock.hasListener, isTrue);

    // 第一帧还没收到时钟事件时会退回真实 now（会把 startedAt 当成很久以前），
    // 先喂一个「起点时刻」让界面进入确定状态，再断言走秒。
    clock.add(startedAt);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('已计时 00:00:00'), findsOneWidget);

    clock.add(startedAt.add(const Duration(seconds: 7)));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('已计时 00:00:07'), findsOneWidget);
  });

  testWidgets('暂停中完成：归档耗时仍是已累计的时长', (tester) async {
    final clock = StreamController<DateTime>();
    addTearDown(() => unawaited(clock.close()));

    await tester.pumpWidget(
      harness(item(status: TaskStatus.done, accumulated: 95), clock.stream),
    );

    expect(find.textContaining('耗时 1m35s'), findsOneWidget);
    expect(find.text('暂停'), findsNothing);
    expect(find.text('取消计时'), findsNothing);
  });
}
