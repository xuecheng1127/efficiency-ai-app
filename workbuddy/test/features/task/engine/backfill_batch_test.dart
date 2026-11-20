import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_template.dart';
import 'package:efficiency_app/features/task/engine/backfill.dart';

/// R5 任务 1：backfill 批量化的回归测试。
///
/// 验收点（对应 R5 报告里的 3.1s → 几十 ms）：
/// - 一次 backfill 只调一次 `lastOccurrenceDates`，不再按模板逐个查；
/// - 需要写入时只调一次 `insertInstances`（批内合并）；
/// - 没有缺失时不发 INSERT（稳态零写入）；
/// - 补齐的日期集合与旧逐条实现完全一致（不漏、不多、不早于 startDate）。
void main() {
  TaskTemplate makeTemplate(
    int id, {
    DateTime? start,
    RepeatMode mode = RepeatMode.daily,
    List<int> days = const [],
  }) {
    return TaskTemplate(
      id: id,
      type: TaskType.study,
      title: '任务 $id',
      repeatMode: mode,
      repeatDays: days,
      startDate: start ?? DateTime(2026, 11, 20),
      alarmEnabled: false,
      createdAt: start ?? DateTime(2026, 11, 20),
    );
  }

  late _CountingSource source;
  final today = DateTime(2026, 11, 20);

  setUp(() => source = _CountingSource());

  test('B1: 1000 个模板只发 2 次查询（取模板 + 取最大日期）+ 1 次批量写', () async {
    source.templates.addAll([for (var i = 1; i <= 1000; i++) makeTemplate(i)]);

    await backfill(source, today);

    expect(source.templateCalls, 1);
    expect(source.lastCalls, 1, reason: '最大日期必须一次 GROUP BY 拿全，不能按模板逐个查');
    expect(source.insertCalls, 1, reason: '缺失实例必须一次批量写入');
    expect(source.inserted.length, 1000, reason: '每个模板补出今天这一条');
  });

  test('B2: 稳态（每个模板都已有今天实例）不发 INSERT', () async {
    source.templates.addAll([for (var i = 1; i <= 1000; i++) makeTemplate(i)]);
    for (var i = 1; i <= 1000; i++) {
      source.last[i] = today;
    }

    await backfill(source, today);

    expect(source.lastCalls, 1);
    expect(source.insertCalls, 0, reason: '没有缺失就不该有写操作');
  });

  test('B3: 补齐区间与旧逐条实现一致（每日 / 单次 / 每周空规则）', () async {
    // 三天没打开：最后一条是 11/17，今天 11/20 → 应补 18/19/20
    source.templates.addAll([
      makeTemplate(1, start: DateTime(2026, 11, 1)),
      makeTemplate(2, start: DateTime(2026, 11, 18), mode: RepeatMode.once),
      makeTemplate(3, start: DateTime(2026, 11, 1), mode: RepeatMode.weekly),
    ]);
    source.last[1] = DateTime(2026, 11, 17);

    await backfill(source, today);

    final dailyDates = source.inserted
        .where((d) => d.template.id == 1)
        .map((d) => d.date)
        .toList();
    expect(dailyDates, [
      DateTime(2026, 11, 18),
      DateTime(2026, 11, 19),
      DateTime(2026, 11, 20),
    ]);

    // once：只在 startDate 当天生成 → 恰好 11/18 一条
    expect(
      source.inserted
          .where((d) => d.template.id == 2)
          .map((d) => d.date)
          .toList(),
      [DateTime(2026, 11, 18)],
    );
    // weekly + 空 repeatDays：matchesRepeatRule 恒 false → 一条都不补
    expect(source.inserted.where((d) => d.template.id == 3), isEmpty);
  });

  test('B4: 回补上限 maxBackfillDays 仍然生效（模板 startDate 很早）', () async {
    source.templates.add(makeTemplate(1, start: DateTime(2020, 1, 1)));

    await backfill(source, today);

    expect(source.inserted.length, maxBackfillDays);
    expect(
      source.inserted.first.date,
      today.subtract(Duration(days: maxBackfillDays - 1)),
    );
  });

  test('B5: 无模板时直接返回，连第二次查询都不发', () async {
    await backfill(source, today);
    expect(source.templateCalls, 1);
    expect(source.lastCalls, 0);
    expect(source.insertCalls, 0);
  });
}

/// 假数据源：把调用次数与写入内容暴露给测试。
class _CountingSource implements BackfillDataSource {
  final List<TaskTemplate> templates = [];
  final Map<int, DateTime> last = {};
  final List<BackfillDraft> inserted = [];

  int templateCalls = 0;
  int lastCalls = 0;
  int insertCalls = 0;

  @override
  Future<List<TaskTemplate>> getActiveTemplates() async {
    templateCalls++;
    return templates;
  }

  @override
  Future<Map<int, DateTime>> lastOccurrenceDates() async {
    lastCalls++;
    return Map<int, DateTime>.from(last);
  }

  @override
  Future<void> insertInstances(List<BackfillDraft> drafts) async {
    insertCalls++;
    inserted.addAll(drafts);
    for (final d in drafts) {
      final cur = last[d.template.id];
      if (cur == null || d.date.isAfter(cur)) last[d.template.id] = d.date;
    }
  }
}
