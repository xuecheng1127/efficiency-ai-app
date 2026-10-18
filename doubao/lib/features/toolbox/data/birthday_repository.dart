import 'package:drift/drift.dart';
import 'package:lunar/lunar.dart';

import '../../../core/database/app_database.dart';

class BirthdayRepository {
  final AppDatabase db;
  BirthdayRepository(this.db);

  Stream<List<BirthdayRow>> watchAll() {
    return (db.select(db.birthdays)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<int> add({
    required String name,
    required int month,
    required int day,
    int? year,
    String calendarType = 'solar',
    String groupTag = '其他',
    int advanceDays = 3,
    String? notes,
  }) {
    return db.into(db.birthdays).insert(
          BirthdaysCompanion.insert(
            name: name.trim(),
            birthdayMonth: month,
            birthdayDay: day,
            birthdayYear: Value(year),
            calendarType: Value(calendarType),
            groupTag: Value(groupTag),
            advanceDays: Value(advanceDays),
            notes: Value(notes),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> softDelete(int id) async {
    await (db.update(db.birthdays)..where((t) => t.id.equals(id)))
        .write(BirthdaysCompanion(
      deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// 计算下一个生日距离今天的天数（返回负数表示今年已过，明年才算）
  /// 农历生日：用 lunar 包转成今年的公历日期
  static int daysUntilNext(BirthdayRow b, DateTime now) {
    DateTime target;
    if (b.calendarType == 'lunar') {
      // 取今年农历该月日对应的公历
      final thisYearLunar = Lunar.fromYmd(
        now.year,
        b.birthdayMonth,
        b.birthdayDay,
      );
      final s = thisYearLunar.getSolar();
      target = DateTime(s.getYear(), s.getMonth(), s.getDay());
      // 如果今年的农历生日已过，用明年
      if (target.isBefore(DateTime(now.year, now.month, now.day))) {
        final nextYearLunar = Lunar.fromYmd(
          now.year + 1,
          b.birthdayMonth,
          b.birthdayDay,
        );
        final s2 = nextYearLunar.getSolar();
        target = DateTime(s2.getYear(), s2.getMonth(), s2.getDay());
      }
    } else {
      target = DateTime(now.year, b.birthdayMonth, b.birthdayDay);
      if (target.isBefore(DateTime(now.year, now.month, now.day))) {
        target = DateTime(now.year + 1, b.birthdayMonth, b.birthdayDay);
      }
    }
    final today = DateTime(now.year, now.month, now.day);
    return target.difference(today).inDays;
  }
}
