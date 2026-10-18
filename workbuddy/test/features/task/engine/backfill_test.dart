import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:efficiency_app/features/task/engine/backfill.dart';

void main() {
  group('matchesRepeatRule 纯逻辑测试（U1–U7）', () {
    // 2026-10-15 是周四；2026-10-12 是周一
    final thursday = DateTime(2026, 10, 15);
    final monday = DateTime(2026, 10, 12);

    test('U1: daily 模板连续 5 天均 true', () {
      for (var i = 0; i < 5; i++) {
        final d = thursday.add(Duration(days: i));
        expect(
          matchesRepeatRule(
            repeatMode: RepeatMode.daily,
            repeatDays: const [],
            startDate: thursday,
            date: d,
          ),
          isTrue,
        );
      }
    });

    test('U2: weekly repeatDays=1,3,5 仅周一/三/五', () {
      const days = [1, 3, 5];
      for (var i = 0; i < 7; i++) {
        final d = monday.add(Duration(days: i));
        expect(
          matchesRepeatRule(
            repeatMode: RepeatMode.weekly,
            repeatDays: days,
            startDate: monday,
            date: d,
          ),
          days.contains(d.weekday),
          reason: 'weekday=${d.weekday} 应为 ${days.contains(d.weekday)}',
        );
      }
    });

    test('U3: weekly repeatDays 空恒 false（不抛异常）', () {
      expect(
        matchesRepeatRule(
          repeatMode: RepeatMode.weekly,
          repeatDays: const [],
          startDate: thursday,
          date: thursday,
        ),
        isFalse,
      );
    });

    test('U4: once 仅当天 true', () {
      expect(
        matchesRepeatRule(
          repeatMode: RepeatMode.once,
          repeatDays: const [],
          startDate: thursday,
          date: thursday,
        ),
        isTrue,
      );
      expect(
        matchesRepeatRule(
          repeatMode: RepeatMode.once,
          repeatDays: const [],
          startDate: thursday,
          date: thursday.subtract(const Duration(days: 1)),
        ),
        isFalse,
      );
      expect(
        matchesRepeatRule(
          repeatMode: RepeatMode.once,
          repeatDays: const [],
          startDate: thursday,
          date: thursday.add(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('U5: daily endDate 之后一天不生成', () {
      final endDate = thursday.add(const Duration(days: 1));
      expect(
        matchesRepeatRule(
          repeatMode: RepeatMode.daily,
          repeatDays: const [],
          startDate: thursday,
          endDate: endDate,
          date: thursday.add(const Duration(days: 2)),
        ),
        isFalse,
      );
    });

    test('U6: daily startDate 之前一天不生成', () {
      expect(
        matchesRepeatRule(
          repeatMode: RepeatMode.daily,
          repeatDays: const [],
          startDate: thursday,
          date: thursday.subtract(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('U7: 跨年边界 12/31 → 1/1 日期连续且均 true', () {
      final dec31 = DateTime(2025, 12, 31);
      final jan1 = DateTime(2026, 1, 1);
      expect(jan1.difference(dec31).inDays, 1, reason: '日期应连续');
      expect(
        matchesRepeatRule(
          repeatMode: RepeatMode.daily,
          repeatDays: const [],
          startDate: dec31,
          date: dec31,
        ),
        isTrue,
      );
      expect(
        matchesRepeatRule(
          repeatMode: RepeatMode.daily,
          repeatDays: const [],
          startDate: dec31,
          date: jan1,
        ),
        isTrue,
      );
    });
  });
}
