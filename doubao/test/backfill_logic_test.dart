import 'package:flutter_test/flutter_test.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/domain/task_template.dart';
import 'package:efficiency_app/features/task/engine/backfill.dart';

/// U1–U7：纯逻辑测试（规格 §5.1，不依赖数据库，必须最先通过）
///
/// 测试对象：
/// - [matchesRepeatRule]（规格 §4.2 重复规则判断）
/// - [backfillOnAppStart]（规格 §4.1 惰性补齐主流程，注入内存 BackfillStore）
void main() {
  group('U1 daily 连续 5 天全 true', () {
    test('daily 模板对 startDate 起连续 5 天逐一判断均返回 true', () {
      final start = DateTime(2026, 10, 12);
      final tpl = _daily(start);
      for (var i = 0; i < 5; i++) {
        final date = start.add(Duration(days: i));
        expect(matchesRepeatRule(tpl, date), isTrue,
            reason: 'daily 应命中任意日期（$date）');
      }
    });
  });

  group('U2 weekly 固定日', () {
    test('repeatDays="1,3,5" 一周 7 天仅周一/三/五为 true', () {
      // 2026-10-12 是周一（Dart weekday 1=周一），10-12..10-18 为一周
      final monday = DateTime(2026, 10, 12);
      final tpl = _weekly([1, 3, 5], monday);
      final expected = <bool>[true, false, true, false, true, false, false];
      for (var i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        expect(
          matchesRepeatRule(tpl, date),
          expected[i],
          reason: 'weekday=${date.weekday}（1=周一）应命中=${expected[i]}',
        );
      }
    });
  });

  group('U3 weekly repeatDays 为空', () {
    test('repeatDays="" 恒为 false 且不抛异常', () {
      final tpl = _weekly(<int>[], DateTime(2026, 10, 12));
      for (var i = 0; i < 7; i++) {
        final date = DateTime(2026, 10, 12).add(Duration(days: i));
        expect(matchesRepeatRule(tpl, date), isFalse,
            reason: '空 repeatDays 永不命中（$date）');
      }
    });
  });

  group('U4 once 单次任务', () {
    test('仅 startDate 当天为 true，前一天/后一天为 false', () {
      final day = DateTime(2026, 10, 12);
      final tpl = _once(day);
      expect(matchesRepeatRule(tpl, day), isTrue);
      expect(
        matchesRepeatRule(tpl, day.subtract(const Duration(days: 1))),
        isFalse,
        reason: '前一天不应命中',
      );
      expect(
        matchesRepeatRule(tpl, day.add(const Duration(days: 1))),
        isFalse,
        reason: '后一天不应命中',
      );
    });
  });

  group('U5 endDate 后不生成', () {
    test('daily 模板 endDate 之后一天不生成实例', () async {
      final start = DateTime(2026, 10, 12);
      final end = DateTime(2026, 10, 14);
      final store = _MemoryBackfillStore()
        ..add(_daily(start, endDate: end));
      // today = endDate 之后一天 → 补齐时 endDate 越界 break，不生成 end 之后实例
      await backfillOnAppStart(store, DateTime(2026, 10, 15));
      expect(store.instances.length, 3, reason: '应只生成 12/13/14 三天');
      expect(
        store.instances.any((i) => i.date.isAfter(end)),
        isFalse,
        reason: 'endDate 之后不应有任何实例',
      );
    });
  });

  group('U6 startDate 前不生成', () {
    test('daily 模板 startDate 之前一天不生成实例', () async {
      final start = DateTime(2026, 10, 12);
      final store = _MemoryBackfillStore()..add(_daily(start));
      // today = startDate 前一天 → from 被 max(from, startDate) 钳到 startDate，
      // 而 startDate > today，while 不执行 → 0 条
      await backfillOnAppStart(store, DateTime(2026, 10, 11));
      expect(store.instances, isEmpty, reason: 'startDate 之前不应生成任何实例');
    });
  });

  group('U7 跨年边界', () {
    test('daily 补齐跨越 12/31→1/1 日期连续无重复无遗漏', () async {
      final start = DateTime(2026, 12, 30);
      final store = _MemoryBackfillStore()..add(_daily(start));
      await backfillOnAppStart(store, DateTime(2027, 1, 2));
      final dates = store.instances.map((i) => i.date).toList()
        ..sort((a, b) => a.compareTo(b));
      expect(dates.length, 4, reason: '12/30、12/31、1/1、1/2 共 4 天');
      expect(dates[0], DateTime(2026, 12, 30));
      expect(dates[1], DateTime(2026, 12, 31));
      expect(dates[2], DateTime(2027, 1, 1));
      expect(dates[3], DateTime(2027, 1, 2));
      // 无重复：去重后数量不变
      expect(dates.toSet().length, 4, reason: '不应有重复日期');
    });
  });
}

// ==================== 测试构造工具 ====================

TaskTemplate _daily(DateTime start, {DateTime? endDate}) {
  return TaskTemplate(
    type: TaskType.study,
    title: '每日学习',
    repeatMode: RepeatRule.daily,
    startDate: start,
    endDate: endDate,
    createdAt: start,
  );
}

TaskTemplate _weekly(List<int> days, DateTime start) {
  return TaskTemplate(
    type: TaskType.study,
    title: '每周固定日',
    repeatMode: RepeatRule.weekly,
    repeatDays: days,
    startDate: start,
    createdAt: start,
  );
}

TaskTemplate _once(DateTime day) {
  return TaskTemplate(
    type: TaskType.fitness,
    title: '单次任务',
    repeatMode: RepeatRule.once,
    startDate: day,
    createdAt: day,
  );
}

/// 内存版 [BackfillStore]：模拟真实数据库语义（幂等 upsert、MAX(occurrenceDate)）
class _MemoryBackfillStore implements BackfillStore {
  final Map<int, TaskTemplate> templates = {};
  final List<({int templateId, DateTime date})> instances = [];
  int _nextId = 1;

  _MemoryBackfillStore add(TaskTemplate tpl) {
    final withId = tpl.copyWith(id: _nextId++);
    templates[withId.id!] = withId;
    return this;
  }

  @override
  Future<List<TaskTemplate>> loadActiveTemplates() async =>
      templates.values.where((t) => t.archivedAt == null).toList();

  @override
  Future<DateTime?> lastGeneratedDate(int templateId) async {
    final dates = instances
        .where((i) => i.templateId == templateId)
        .map((i) => i.date);
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  @override
  Future<bool> upsertInstance(TaskTemplate template, DateTime date) async {
    final exists = instances.any(
      (i) => i.templateId == template.id && _sameDay(i.date, date),
    );
    if (exists) return false;
    instances.add((templateId: template.id!, date: date));
    return true;
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
