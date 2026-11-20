import 'package:efficiency_app/core/services/home_widget_service.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_instance.dart';
import 'package:efficiency_app/features/task/domain/task_repository.dart';
import 'package:efficiency_app/features/task/domain/task_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// R3：桌面小组件快照口径验证（完成计数 / 前 3 条未完成 / 空态）
void main() {
  final fixedDate = DateTime(2026, 11, 19); // 周四

  TaskWithOccurrence makeOcc(String title, TaskStatus status) {
    final template = TaskTemplate(
      type: TaskType.study,
      title: title,
      repeatMode: RepeatRule.once,
      startDate: fixedDate,
      createdAt: fixedDate,
    );
    final occurrence = TaskInstance(
      templateId: 1,
      occurrenceDate: fixedDate,
      titleSnapshot: title,
      typeSnapshot: TaskType.study,
      status: status,
    );
    return TaskWithOccurrence(task: template, occurrence: occurrence);
  }

  test('完成计数正确，未完成只取前 3 条，openCount 保留真实未完成数', () {
    final tasks = [
      makeOcc('已完成任务 A', TaskStatus.done),
      makeOcc('已完成任务 B', TaskStatus.done),
      makeOcc('未完成一', TaskStatus.todo),
      makeOcc('未完成二', TaskStatus.inProgress),
      makeOcc('未完成三', TaskStatus.todo),
      makeOcc('未完成四', TaskStatus.todo),
    ];

    final snapshot = HomeWidgetService.buildSnapshot(tasks, now: fixedDate);

    expect(snapshot.total, 6);
    expect(snapshot.done, 2);
    expect(snapshot.openCount, 4);
    expect(snapshot.openTitles, ['未完成一', '未完成二', '未完成三']);
  });

  test('空列表快照：总数 0、未完成 0、标题为空', () {
    final snapshot = HomeWidgetService.buildSnapshot(const [], now: fixedDate);

    expect(snapshot.total, 0);
    expect(snapshot.done, 0);
    expect(snapshot.openCount, 0);
    expect(snapshot.openTitles, isEmpty);
  });

  test('纯空白标题不计入未完成列表', () {
    final tasks = [
      makeOcc('   ', TaskStatus.todo),
      makeOcc('有效任务', TaskStatus.todo),
    ];

    final snapshot = HomeWidgetService.buildSnapshot(tasks, now: fixedDate);

    expect(snapshot.openCount, 1);
    expect(snapshot.openTitles, ['有效任务']);
  });

  test('日期标签按固定日期生成中文周几', () {
    final snapshot = HomeWidgetService.buildSnapshot(const [], now: fixedDate);

    expect(snapshot.dateLabel, '11月19日 周四');
  });
}
