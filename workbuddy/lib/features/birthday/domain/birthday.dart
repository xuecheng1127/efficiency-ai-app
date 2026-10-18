/// ============================================================================
/// 朋友生日：实体 + 下一次生日推算（**纯 Dart**，可直接单测）
/// ============================================================================
///
/// 历法换算全部走 `lunar` 包，本文件**不含任何手写历法算法**：
/// - 农历 → 公历：`Lunar.fromYmd(年, 月, 日).getSolar()`
/// - 是否闰月：`LunarYear.fromYear(年).getLeapMonth()`
library;

import 'package:lunar/lunar.dart';

/// 生日历法。
enum BirthdayCalendar {
  solar(id: 'solar', label: '公历'),
  lunar(id: 'lunar', label: '农历');

  const BirthdayCalendar({required this.id, required this.label});

  final String id;
  final String label;

  static BirthdayCalendar byId(String? id) =>
      id == 'lunar' ? BirthdayCalendar.lunar : BirthdayCalendar.solar;
}

/// 一条生日记录（映射 `birthdays` 表）。
class Birthday {
  const Birthday({
    required this.id,
    required this.name,
    this.birthdayYear,
    required this.month,
    required this.day,
    required this.calendar,
    this.groupTag,
    required this.advanceDays,
    this.notes,
    required this.createdAt,
    this.deletedAt,
  });

  final int id;
  final String name;
  final int? birthdayYear;

  /// 公历或农历的「月」（1–12）
  final int month;

  /// 公历或农历的「日」（1–31 / 1–30）
  final int day;

  final BirthdayCalendar calendar;
  final String? groupTag;
  final int advanceDays;
  final String? notes;
  final DateTime createdAt;
  final DateTime? deletedAt;

  String get groupLabel {
    final g = groupTag?.trim() ?? '';
    return g.isEmpty ? '未分组' : g;
  }
}

/// 下一次生日的推算结果。
class BirthdayOccurrence {
  const BirthdayOccurrence({
    required this.birthday,
    required this.nextDate,
    required this.daysUntil,
    required this.lunarYear,
    required this.hasLeapMonth,
    required this.dateLabel,
  });

  final Birthday birthday;

  /// 下一次生日的**公历**日期（当天 0 点）
  final DateTime nextDate;

  /// 距今还有几天（0 = 今天）
  final int daysUntil;

  /// 该次生日所在的农历年（公历生日时 = 公历年）
  final int lunarYear;

  /// 农历生日且该农历年**恰好有同名闰月**（需要在 UI 标注：按非闰月计算）
  final bool hasLeapMonth;

  /// 展示用日期文案：`10月20日` / `农历九月初八`
  final String dateLabel;

  bool get isToday => daysUntil == 0;

  /// 7 天内高亮
  bool get isSoon => daysUntil <= 7;

  /// 一周内的问候语（列表卡片的副标题）
  String get countdownLabel {
    if (daysUntil == 0) return '就是今天 🎂';
    if (daysUntil == 1) return '明天';
    return '还有 $daysUntil 天';
  }
}

/// 推算「下一次生日」。
///
/// 规则：
/// - 公历：今年没过就是今年，过了就明年；2 月 29 日在平年按 **2 月 28 日**（常见约定）；
/// - 农历：从**当前农历年**起逐年尝试，用 `Lunar.fromYmd(...).getSolar()` 转公历；
///   若该年这个农历月没有 30 日（小月），跳过该年继续往后找；
/// - 返回 null 只在输入本身非法时（月/日越界），正常数据永远有下一次。
BirthdayOccurrence? nextBirthdayOf(Birthday b, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (b.month < 1 || b.month > 12 || b.day < 1 || b.day > 31) return null;

  if (b.calendar == BirthdayCalendar.solar) {
    for (var year = today.year; year <= today.year + 2; year++) {
      final date = _solarDate(year, b.month, b.day);
      if (date == null || date.isBefore(today)) continue;
      return BirthdayOccurrence(
        birthday: b,
        nextDate: date,
        daysUntil: date.difference(today).inDays,
        lunarYear: year,
        hasLeapMonth: false,
        dateLabel: '${b.month}月${b.day}日',
      );
    }
    return null;
  }

  // 农历：以「今天的农历年」为起点
  final lunarToday = Lunar.fromDate(today);
  final startLunarYear = lunarToday.getYear();
  for (var ly = startLunarYear; ly <= startLunarYear + 2; ly++) {
    final solarDate = _lunarToSolar(ly, b.month, b.day);
    if (solarDate == null || solarDate.isBefore(today)) continue;
    final leapMonth = LunarYear.fromYear(ly).getLeapMonth();
    final lunar = Lunar.fromYmd(ly, b.month, b.day);
    return BirthdayOccurrence(
      birthday: b,
      nextDate: solarDate,
      daysUntil: solarDate.difference(today).inDays,
      lunarYear: ly,
      hasLeapMonth: leapMonth == b.month,
      dateLabel: '农历${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}',
    );
  }
  return null;
}

/// 批量推算 + 排序：**按距离生日天数升序**（7 天内的自然浮到最上面）。
List<BirthdayOccurrence> upcomingBirthdays(
  List<Birthday> birthdays,
  DateTime now,
) {
  final out = <BirthdayOccurrence>[];
  for (final b in birthdays) {
    if (b.deletedAt != null) continue;
    final o = nextBirthdayOf(b, now);
    if (o != null) out.add(o);
  }
  out.sort((a, b) {
    final c = a.daysUntil.compareTo(b.daysUntil);
    return c != 0 ? c : a.birthday.name.compareTo(b.birthday.name);
  });
  return out;
}

/// 公历日期构造：**非法组合返回 null**（而不是让 DateTime 默默进位）。
/// 2 月 29 日落在平年时退到 2 月 28 日。
DateTime? _solarDate(int year, int month, int day) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  if (day <= daysInMonth) return DateTime(year, month, day);
  if (month == 2 && day == 29) return DateTime(year, 2, 28);
  return null;
}

/// 农历 → 公历；该农历年没有这一天（如小月三十）时返回 null。
DateTime? _lunarToSolar(int lunarYear, int month, int day) {
  try {
    final solar = Lunar.fromYmd(lunarYear, month, day).getSolar();
    return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
  } catch (_) {
    return null;
  }
}
