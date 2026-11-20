import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// R1：索引与大数据量查询验证
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => await db.close());

  test('批量插入 1000 条任务实例后按日期+状态查询不报错', () async {
    final today = DateTime(2026, 10, 15);
    for (var i = 0; i < 1000; i++) {
      await db.into(db.taskInstances).insert(
            TaskInstancesCompanion.insert(
              templateId: i + 1,
              occurrenceDate: today,
              titleSnapshot: '任务 $i',
              typeSnapshot: 'single',
              status: i % 2 == 0 ? 'done' : 'pending',
            ),
          );
    }

    final pending = await (db.select(db.taskInstances)
          ..where((t) => t.occurrenceDate.equals(today) & t.status.equals('pending')))
        .get();
    expect(pending.length, 500);

    final done = await (db.select(db.taskInstances)
          ..where((t) => t.occurrenceDate.equals(today) & t.status.equals('done')))
        .get();
    expect(done.length, 500);
  });

  test('日记/采购/热量/生日/提醒按索引列查询不报错', () async {
    await db.into(db.diaries).insert(
          DiariesCompanion.insert(diaryDate: 20261015, createdAt: 1, updatedAt: 1),
        );
    await db.into(db.shoppingItems).insert(
          ShoppingItemsCompanion.insert(name: '苹果', createdAt: 1),
        );
    await db.into(db.calorieEntries).insert(
          CalorieEntriesCompanion.insert(entryDate: 20261015, meal: 'lunch', name: '饭', kcal: 500, createdAt: 1),
        );
    await db.into(db.birthdays).insert(
          BirthdaysCompanion.insert(name: '张三', birthdayMonth: 10, birthdayDay: 15, createdAt: 1),
        );
    await db.into(db.locationReminders).insert(
          LocationRemindersCompanion.insert(title: '买菜', placeName: '超市', latitude: 32.63, longitude: 117.98, createdAt: 1),
        );

    final d = await (db.select(db.diaries)..where((x) => x.diaryDate.equals(20261015))).get();
    expect(d.length, 1);
    final s = await (db.select(db.shoppingItems)..where((x) => x.checked.equals(0))).get();
    expect(s.length, 1);
    final c = await (db.select(db.calorieEntries)..where((x) => x.entryDate.equals(20261015))).get();
    expect(c.length, 1);
    final b = await (db.select(db.birthdays)
          ..where((x) => x.birthdayMonth.equals(10) & x.birthdayDay.equals(15))).get();
    expect(b.length, 1);
    final l = await (db.select(db.locationReminders)..where((x) => x.enabled.equals(1))).get();
    expect(l.length, 1);
  });
}
