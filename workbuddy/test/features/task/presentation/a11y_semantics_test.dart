import 'dart:async';

import 'package:efficiency_app/core/widgets/empty_state.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_instance.dart';
import 'package:efficiency_app/features/task/presentation/widgets/task_tile.dart';
import 'package:efficiency_app/features/task/providers/task_ticker_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// R3 任务 1：无障碍语义。
///
/// 这里测的不是「有没有写 Semantics」，而是**读屏实际会念出什么**：
/// - 卡片里状态圆点（图形）必须有文字版本，并且和标题在同一个节点上；
/// - 三个纯图标按钮必须带上任务名，否则一排三条任务分不清点的是哪条；
/// - 计时按钮把可见文字换成整句标签后，不能再重复念一遍「暂停」。
void main() {
  const title = '买牛奶';

  TaskInstance instance({
    required TaskStatus status,
    int accumulatedSeconds = 0,
    bool paused = false,
  }) {
    return TaskInstance(
      id: 1,
      templateId: 1,
      occurrenceDate: DateTime(2026, 11, 19),
      titleSnapshot: title,
      typeSnapshot: TaskType.study,
      status: status,
      startedAt: status == TaskStatus.inProgress && !paused
          ? DateTime(2026, 11, 19, 9)
          : null,
      accumulatedSeconds: accumulatedSeconds,
    );
  }

  Widget harness(Widget child) {
    return ProviderScope(
      overrides: [
        // 用空流：不需要真的跳秒，只要不因为没时钟而崩
        taskTickerProvider.overrideWith(
          (ref) => const Stream<DateTime>.empty(),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  Widget tile(TaskInstance item) => TaskTile(
    instance: item,
    onToggle: () {},
    onPause: () {},
    onResume: () {},
    onCancelTimer: () {},
    onComplete: () {},
    onDelete: () {},
    onAlarm: () {},
  );

  testWidgets('未开始：状态与标题合并在同一节点，完成按钮带任务名', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(tile(instance(status: TaskStatus.todo))));

    // 状态圆点是纯图形，读屏拿到的必须是「未开始」这四个字，
    // 而且要和标题在**同一个**节点里（MergeSemantics），否则会多一次空停。
    final merged = tester.getSemantics(find.text(title));
    expect(merged.label, contains('未开始'));
    expect(merged.label, contains(title));

    // 纯图标按钮：tooltip 就是读屏标签，必须带任务名
    expect(find.bySemanticsLabel('标记完成「$title」'), findsOneWidget);
    expect(find.bySemanticsLabel('删除「$title」'), findsOneWidget);
    expect(find.bySemanticsLabel('给「$title」设置闹钟'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('计时中：暂停/取消按钮念整句，且不重复念一次裸文字', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(tile(instance(status: TaskStatus.inProgress))),
    );

    expect(find.bySemanticsLabel('暂停「$title」的计时'), findsOneWidget);
    expect(find.bySemanticsLabel('取消「$title」的计时'), findsOneWidget);

    // excludeSemantics 生效：不存在一个只念「暂停」的独立节点
    expect(find.bySemanticsLabel('暂停'), findsNothing);

    final node = tester.getSemantics(find.bySemanticsLabel('暂停「$title」的计时'));
    expect(node.flagsCollection.isButton, isTrue);
    // 有 onTap 才算真能按下去（只念不给动作是「只能听、按不动」）
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });

  testWidgets('已完成：状态念「已完成」，完成按钮变成不可用提示', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(tile(instance(status: TaskStatus.done, accumulatedSeconds: 65))),
    );

    final merged = tester.getSemantics(find.text(title));
    expect(merged.label, contains('已完成'));
    expect(find.bySemanticsLabel('「$title」已完成'), findsOneWidget);
    expect(find.bySemanticsLabel('已完成'), findsNothing);

    handle.dispose();
  });

  testWidgets('空态：图标不念「图片」，标题与说明合成一句', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        const EmptyState(
          icon: Icons.task_alt,
          title: '今日暂无任务',
          subtitle: '点击右下角 + 创建你的第一个任务',
        ),
      ),
    );

    final node = tester.getSemantics(find.text('今日暂无任务'));
    expect(node.label, contains('今日暂无任务'));
    expect(node.label, contains('点击右下角'), reason: '副标题必须一起念出来');

    handle.dispose();
  });
}
