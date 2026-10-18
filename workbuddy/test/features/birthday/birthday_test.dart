import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart'
    hide Birthday;
import 'package:efficiency_app/features/birthday/data/birthday_repository_impl.dart';
import 'package:efficiency_app/features/birthday/domain/birthday.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunar/lunar.dart';

/// 朋友生日：下一次生日推算（公历 / 农历 / 闰月 / 排序）+ 仓库 CRUD。
void main() {
  group('nextBirthdayOf · 公历', () {
    final now = DateTime(2026, 10, 18);

    Birthday solar(int month, int day, {int? year}) => Birthday(
      id: 1,
      name: '测试',
      birthdayYear: year,
      month: month,
      day: day,
      calendar: BirthdayCalendar.solar,
      advanceDays: 3,
      createdAt: now,
    );

    test('今年还没到 → 就是今年，天数正确', () {
      final occ = nextBirthdayOf(solar(10, 20), now)!;
      expect(occ.nextDate, DateTime(2026, 10, 20));
      expect(occ.daysUntil, 2);
      expect(occ.isSoon, isTrue);
    });

    test('今天 → daysUntil = 0', () {
      final occ = nextBirthdayOf(solar(10, 18), now)!;
      expect(occ.daysUntil, 0);
      expect(occ.isToday, isTrue);
      expect(occ.countdownLabel, contains('今天'));
    });

    test('今年已过 → 顺延到明年', () {
      final occ = nextBirthdayOf(solar(10, 17), now)!;
      expect(occ.nextDate, DateTime(2027, 10, 17));
      expect(occ.daysUntil, greaterThan(300));
    });

    test('2 月 29 日：平年按 2 月 28 日', () {
      final occ = nextBirthdayOf(solar(2, 29), now)!;
      expect(occ.nextDate, DateTime(2027, 2, 28));
      expect(occ.dateLabel, '2月29日', reason: '展示仍按用户的原始日期');
    });

    test('非法月日返回 null（不崩）', () {
      expect(nextBirthdayOf(solar(13, 1), now), isNull);
      expect(nextBirthdayOf(solar(1, 32), now), isNull);
    });
  });

  group('nextBirthdayOf · 农历（全部交给 lunar 包）', () {
    final now = DateTime(2026, 10, 18);

    Birthday lunar(int month, int day) => Birthday(
      id: 1,
      name: '农历测试',
      month: month,
      day: day,
      calendar: BirthdayCalendar.lunar,
      advanceDays: 3,
      createdAt: now,
    );

    test('换算出来的公历日期，反查农历必须回到同月同日', () {
      for (final md in const [
        [1, 1],
        [5, 5],
        [8, 15],
        [9, 9],
        [12, 8],
      ]) {
        final occ = nextBirthdayOf(lunar(md[0], md[1]), now);
        expect(occ, isNotNull, reason: '农历 ${md[0]}月${md[1]}日 应该有下一次');
        final back = Lunar.fromDate(occ!.nextDate);
        expect(back.getMonth(), md[0], reason: '农历 ${md[0]}/${md[1]} 换算后月不对');
        expect(back.getDay(), md[1], reason: '农历 ${md[0]}/${md[1]} 换算后日不对');
        expect(occ.daysUntil, greaterThanOrEqualTo(0));
      }
    });

    test('结果一定是「今天或将来」的公历日期', () {
      final occ = nextBirthdayOf(lunar(1, 1), now)!;
      expect(occ.nextDate.isBefore(DateTime(2026, 10, 18)), isFalse);
      expect(occ.dateLabel, startsWith('农历'));
    });

    test('该农历年有同名闰月时，标记 hasLeapMonth', () {
      // 动态找一年有闰月的（不写死年份，历法数据由 lunar 包提供）
      int? leapMonth;
      int? leapYear;
      for (var y = 2020; y <= 2040; y++) {
        final m = LunarYear.fromYear(y).getLeapMonth();
        if (m > 0) {
          leapMonth = m;
          leapYear = y;
          break;
        }
      }
      expect(leapMonth, isNotNull, reason: '40 年内必然有闰月');

      // 取该农历年年中一个公历日期作为「今天」，让下一次生日落在该年
      final leapSolar = Lunar.fromYmd(leapYear!, leapMonth!, 1).getSolar();
      final today = DateTime(
        leapSolar.getYear(),
        leapSolar.getMonth(),
        leapSolar.getDay() - 1,
      );
      final occ = nextBirthdayOf(lunar(leapMonth, 10), today)!;
      expect(occ.lunarYear, leapYear);
      expect(occ.hasLeapMonth, isTrue, reason: '闰$leapMonth 月要在 UI 标注');
    });
  });

  group('upcomingBirthdays', () {
    test('按距离升序；已删除的不出现', () {
      final now = DateTime(2026, 10, 18);
      Birthday b(int id, String name, int day, {DateTime? deleted}) => Birthday(
        id: id,
        name: name,
        month: 10,
        day: day,
        calendar: BirthdayCalendar.solar,
        advanceDays: 3,
        createdAt: now,
        deletedAt: deleted,
      );
      final list = upcomingBirthdays([
        b(1, 'C', 25),
        b(2, 'A', 19),
        b(3, 'B', 24),
        b(4, 'D', 20, deleted: now),
      ], now);

      expect(list.map((e) => e.birthday.name), ['A', 'B', 'C']);
      expect(list.first.daysUntil, 1);
    });
  });

  group('BirthdayRepositoryImpl（内存 SQLite）', () {
    late AppDatabase db;
    late BirthdayRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = BirthdayRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('名字为空不落库', () async {
      expect(
        await repo.create(
          name: '  ',
          month: 1,
          day: 1,
          calendar: BirthdayCalendar.solar,
        ),
        isNull,
      );
      expect(await repo.all(), isEmpty);
    });

    test('新建后能读到，历法/提前天数/分组都保存正确', () async {
      final id = await repo.create(
        name: '妈妈',
        month: 6,
        day: 12,
        calendar: BirthdayCalendar.lunar,
        year: 1968,
        groupTag: '家人',
        advanceDays: 7,
        notes: '喜欢花',
      );
      final b = await repo.findById(id!);
      expect(b, isNotNull);
      expect(b!.name, '妈妈');
      expect(b.calendar, BirthdayCalendar.lunar);
      expect(b.month, 6);
      expect(b.day, 12);
      expect(b.birthdayYear, 1968);
      expect(b.groupTag, '家人');
      expect(b.advanceDays, 7);
      expect(b.notes, '喜欢花');
    });

    test('更新只改传入的字段；clearYear 能清空年份', () async {
      final id = (await repo.create(
        name: '小王',
        month: 3,
        day: 4,
        calendar: BirthdayCalendar.solar,
        year: 2000,
      ))!;
      await repo.update(id, advanceDays: 1, clearYear: true);

      final b = (await repo.findById(id))!;
      expect(b.name, '小王');
      expect(b.month, 3);
      expect(b.advanceDays, 1);
      expect(b.birthdayYear, isNull);
    });

    test('软删除后消失，restore 可以撤销', () async {
      final id = (await repo.create(
        name: '小李',
        month: 7,
        day: 7,
        calendar: BirthdayCalendar.solar,
      ))!;
      await repo.softDelete(id);
      expect(await repo.all(), isEmpty);

      await repo.restore(id);
      expect(await repo.all(), hasLength(1));
    });
  });
}
