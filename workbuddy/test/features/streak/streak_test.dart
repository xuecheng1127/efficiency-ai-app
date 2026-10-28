import 'package:efficiency_app/features/streak/domain/streak.dart';
import 'package:flutter_test/flutter_test.dart';

/// 火花计算的口径回归（评审验收项）：
/// - 连续 3 天 → 火花 3
/// - 跳过 1 天 → 归零
/// - 今天没做但昨天做了 → 不扣
void main() {
  // 固定「今天」= 2026-10-28，测试不依赖运行时的真实日期。
  final today = DateTime(2026, 10, 28);
  DateTime daysAgo(int n) => DateTime(2026, 10, 28 - n);

  group('computeStreak · 当前连续天数', () {
    test('连续 3 天（含今天）→ 火花 3', () {
      final s = computeStreak(
        doneDays: [daysAgo(0), daysAgo(1), daysAgo(2)],
        now: today,
      );

      expect(s.currentDays, 3);
      expect(s.doneToday, isTrue);
      expect(s.longestDays, 3);
    });

    test('今天没做，但昨天/前天/大前天都做了 → 仍是 3（不扣）', () {
      final s = computeStreak(
        doneDays: [daysAgo(1), daysAgo(2), daysAgo(3)],
        now: today,
      );

      expect(s.currentDays, 3, reason: '当天还没过完，不能因为早上没做就清零');
      expect(s.doneToday, isFalse);
    });

    test('跳过 1 天（昨天没做，今天也没做）→ 归零', () {
      final s = computeStreak(
        doneDays: [daysAgo(2), daysAgo(3), daysAgo(4)],
        now: today,
      );

      expect(s.currentDays, 0);
      expect(s.doneToday, isFalse);
    });

    test('今天做了，但昨天断了 → 从今天重新起算 1', () {
      final s = computeStreak(
        doneDays: [daysAgo(0), daysAgo(2), daysAgo(3)],
        now: today,
      );

      expect(s.currentDays, 1);
      expect(s.doneToday, isTrue);
    });

    test('昨天做了、前天断了 → 火花 1（昨天那段还在）', () {
      final s = computeStreak(doneDays: [daysAgo(1), daysAgo(3)], now: today);

      expect(s.currentDays, 1);
    });

    test('完全没有完成记录 → 0', () {
      final s = computeStreak(doneDays: const [], now: today);

      expect(s.currentDays, 0);
      expect(s.longestDays, 0);
      expect(s.doneToday, isFalse);
    });
  });

  group('computeStreak · 历史最长', () {
    test('跨月连续（10-01 → 10-03）算 3 天', () {
      final s = computeStreak(
        doneDays: [
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 3),
          // 断档
          DateTime(2026, 10, 20),
        ],
        now: DateTime(2026, 10, 21),
      );

      expect(s.longestDays, 3);
      expect(s.currentDays, 1, reason: '昨天(10-20)做了，但 10-19 断了，火花为 1');
    });

    test('最长段在历史里，当前只有 1 → 取历史最长', () {
      final s = computeStreak(
        doneDays: [
          ...List.generate(7, (i) => DateTime(2026, 9, 1 + i)),
          DateTime(2026, 10, 27),
          DateTime(2026, 10, 28),
        ],
        now: today,
      );

      expect(s.longestDays, 7);
      expect(s.currentDays, 2);
    });

    test('带时分秒的完成时间被归一化到日期，同一天多条只算一天', () {
      final s = computeStreak(
        doneDays: [
          DateTime(2026, 10, 28, 0, 5),
          DateTime(2026, 10, 28, 23, 59),
          DateTime(2026, 10, 27, 8, 30),
        ],
        now: DateTime(2026, 10, 28, 23, 59, 59),
      );

      expect(s.currentDays, 2);
      expect(s.longestDays, 2);
    });

    test('未来日期不参与统计（时钟被调快也不会凭空多出火花）', () {
      final s = computeStreak(
        doneDays: [daysAgo(0), DateTime(2026, 10, 30)],
        now: today,
      );

      expect(s.currentDays, 1);
      expect(s.longestDays, 1);
    });
  });

  group('勋章门槛', () {
    test('五档门槛与名称与需求一致', () {
      expect(kStreakBadges.map((b) => b.days).toList(), [3, 7, 30, 100, 365]);
      expect(kStreakBadges.map((b) => b.name).toList(), [
        '初露锋芒',
        '一周不断',
        '月度坚持',
        '百日筑基',
        '全年无休',
      ]);
    });

    test('3 天解锁 1 枚，下一枚是 7 天', () {
      expect(unlockedBadges(3).map((b) => b.days), [3]);
      expect(nextBadge(3)!.days, 7);
    });

    test('0 天全部未解锁，下一枚是 3 天', () {
      expect(unlockedBadges(0), isEmpty);
      expect(nextBadge(0)!.days, 3);
    });

    test('365 天全部解锁', () {
      expect(unlockedBadges(365), hasLength(5));
      expect(nextBadge(365), isNull);
    });
  });
}
