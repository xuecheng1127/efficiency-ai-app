import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_instance.dart';
import 'package:efficiency_app/features/widget/application/today_widget_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// R2 · 桌面小组件的数据折叠（纯函数，不碰 Android / HomeWidget）。
void main() {
  final day = DateTime(2026, 11, 19, 9, 30); // 周四

  TaskInstance task(
    String title, {
    TaskStatus status = TaskStatus.todo,
    DateTime? deletedAt,
  }) {
    return TaskInstance(
      id: title.hashCode.abs() % 100000,
      templateId: 1,
      occurrenceDate: DateTime(2026, 11, 19),
      titleSnapshot: title,
      typeSnapshot: TaskType.study,
      status: status,
      accumulatedSeconds: 0,
      deletedAt: deletedAt,
    );
  }

  group('buildTodayWidgetData', () {
    test('日期文案带星期（11月19日 · 周四）', () {
      final data = buildTodayWidgetData(const [], day);
      expect(data.dateLabel, '11月19日 · 周四');
    });

    test('统计完成数 / 总数，并只取前 3 条未完成', () {
      final data = buildTodayWidgetData([
        task('背单词', status: TaskStatus.done),
        task('跑步'),
        task('写周报'),
        task('看书'),
        task('整理房间'),
      ], day);

      expect(data.done, 1);
      expect(data.total, 5);
      expect(data.progressLabel, '已完成 1 / 5');
      expect(data.progressPercent, 20);
      expect(data.pendingTitles, ['跑步', '写周报', '看书']);
      expect(data.remaining, 4, reason: '还有 1 条没显示，remainder 要能算出来');
      expect(data.numberedTitleAt(0), '1. 跑步');
      expect(data.numberedTitleAt(2), '3. 看书');
      expect(data.numberedTitleAt(3), '', reason: '第 4 条没有位置，必须是空串');
    });

    test('已删除的实例不计入统计', () {
      final data = buildTodayWidgetData([
        task('正常任务'),
        task('删掉的任务', deletedAt: DateTime(2026, 11, 19, 8)),
      ], day);

      expect(data.total, 1);
      expect(data.pendingTitles, ['正常任务']);
    });

    test('进行中的任务算「未完成」（它还没做完）', () {
      final data = buildTodayWidgetData([
        task('在跑的', status: TaskStatus.inProgress),
        task('做完的', status: TaskStatus.done),
      ], day);

      expect(data.done, 1);
      expect(data.remaining, 1);
      expect(data.pendingTitles, ['在跑的']);
    });

    test('空列表：总数 0，空态文案是「今天没有任务」', () {
      final data = buildTodayWidgetData(const [], day);
      expect(data.total, 0);
      expect(data.done, 0);
      expect(data.progressPercent, 0, reason: '总数为 0 时不能除零');
      expect(data.emptyLabel, '今天没有任务');
      expect(data.numberedTitleAt(0), '');
    });

    test('全部完成：空态文案是「今天的任务都完成了」', () {
      final data = buildTodayWidgetData([
        task('a', status: TaskStatus.done),
        task('b', status: TaskStatus.done),
      ], day);

      expect(data.progressPercent, 100);
      expect(data.remaining, 0);
      expect(data.emptyLabel, '今天的任务都完成了');
    });

    test('星期映射覆盖周一与周日（边界）', () {
      expect(TodayWidgetData.dateLabelOf(DateTime(2026, 11, 16)), '11月16日 · 周一');
      expect(TodayWidgetData.dateLabelOf(DateTime(2026, 11, 22)), '11月22日 · 周日');
    });
  });
}
