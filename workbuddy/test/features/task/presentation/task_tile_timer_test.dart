import 'dart:async';

import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_instance.dart';
import 'package:efficiency_app/features/task/presentation/widgets/task_tile.dart';
import 'package:efficiency_app/features/task/providers/task_ticker_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// P0-3 回归测试：**秒数必须真的在跳**。
///
/// 旧行为：耗时只在 build 里算一次，界面进入后不再重建 ——
/// 「点一下变蓝，之后再也不动」（评审用 t0 / t+10s 两张截图完全一致来证明）。
///
/// 这里分两层证明：
/// 1. `taskTickerProvider` 真的是每秒一跳（真实时钟，测间隔）；
/// 2. 时钟一跳，`TaskTile` 的文本就跟着变（可控流，逐帧断言，确定性）。
void main() {
  final startedAt = DateTime(2026, 10, 18, 4, 0, 0);

  TaskInstance instance({
    required TaskStatus status,
    int accumulatedSeconds = 0,
  }) {
    return TaskInstance(
      id: 1,
      templateId: 1,
      occurrenceDate: DateTime(2026, 10, 18),
      titleSnapshot: '背单词',
      typeSnapshot: TaskType.study,
      status: status,
      startedAt: status == TaskStatus.inProgress ? startedAt : null,
      accumulatedSeconds: accumulatedSeconds,
    );
  }

  Widget harness(TaskInstance item, Stream<DateTime> clock) {
    return ProviderScope(
      overrides: [taskTickerProvider.overrideWith((ref) => clock)],
      child: MaterialApp(
        home: Scaffold(
          body: TaskTile(
            instance: item,
            onToggle: () {},
            onComplete: () {},
            onDelete: () {},
            onAlarm: () {},
          ),
        ),
      ),
    );
  }

  /// 推一次时钟事件并让界面稳定下来。
  ///
  /// 两帧是必要的：第一帧消化流事件，第二帧渲染 Riverpod 通知后的新状态。
  Future<void> tick(
    WidgetTester tester,
    StreamController<DateTime> clock,
    DateTime at,
  ) async {
    clock.add(at);
    await tester.pump();
    await tester.pump();
  }

  test('taskTickerProvider 约每秒一跳（真实时钟）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ticks = <DateTime>[];
    final sub = container.listen<AsyncValue<DateTime>>(taskTickerProvider, (
      _,
      next,
    ) {
      final value = next.value;
      if (value != null) ticks.add(value);
    }, fireImmediately: true);

    await Future<void>.delayed(const Duration(milliseconds: 2400));
    sub.close();

    expect(ticks.length, greaterThanOrEqualTo(3), reason: '应至少 3 个时刻');
    for (var i = 1; i < ticks.length; i++) {
      final gap = ticks[i].difference(ticks[i - 1]).inMilliseconds;
      expect(gap, inInclusiveRange(700, 1400), reason: '第 $i 跳间隔应约为 1 秒');
    }
  });

  testWidgets('计时中：时钟每跳一次，秒数加一（00:00:00 → 00:00:03）', (tester) async {
    final clock = StreamController<DateTime>();
    // 不 await close：控制器还有订阅者时会一直等，teardown 会假死
    addTearDown(() {
      unawaited(clock.close());
    });

    await tester.pumpWidget(
      harness(instance(status: TaskStatus.inProgress), clock.stream),
    );

    await tick(tester, clock, startedAt);
    expect(find.textContaining('已计时 00:00:00'), findsOneWidget);

    await tick(tester, clock, startedAt.add(const Duration(seconds: 1)));
    expect(
      find.textContaining('已计时 00:00:01'),
      findsOneWidget,
      reason: '1 秒后必须变成 00:00:01',
    );

    await tick(tester, clock, startedAt.add(const Duration(seconds: 2)));
    expect(find.textContaining('已计时 00:00:02'), findsOneWidget);

    await tick(tester, clock, startedAt.add(const Duration(seconds: 3)));
    expect(
      find.textContaining('已计时 00:00:03'),
      findsOneWidget,
      reason: '三秒后必须是 00:00:03 —— 证明是累计跳动而不是原地重算',
    );
  });

  testWidgets('未开始：不显示「已计时」', (tester) async {
    final clock = StreamController<DateTime>();
    addTearDown(() {
      unawaited(clock.close());
    });

    await tester.pumpWidget(
      harness(instance(status: TaskStatus.todo), clock.stream),
    );
    await tick(tester, clock, startedAt.add(const Duration(seconds: 5)));

    expect(find.textContaining('已计时'), findsNothing);
    expect(find.textContaining('背单词'), findsOneWidget);
  });

  testWidgets('已完成：显示归档耗时（1m5s），不显示「已计时」', (tester) async {
    final clock = StreamController<DateTime>();
    addTearDown(() {
      unawaited(clock.close());
    });

    await tester.pumpWidget(
      harness(
        instance(status: TaskStatus.done, accumulatedSeconds: 65),
        clock.stream,
      ),
    );
    await tick(tester, clock, startedAt.add(const Duration(seconds: 5)));

    expect(find.textContaining('耗时 1m5s'), findsOneWidget);
    expect(find.textContaining('已计时'), findsNothing);
  });
}
