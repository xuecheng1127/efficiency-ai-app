import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart'
    hide CalorieEntry;
import 'package:efficiency_app/features/calorie/data/calorie_repository_impl.dart';
import 'package:efficiency_app/features/calorie/domain/calorie.dart';
import 'package:flutter_test/flutter_test.dart';

/// 每日热量：餐次自动判断 / 汇总 / 分组 / 目标公式 / 仓库。
void main() {
  group('MealType.forHour', () {
    test('6–10 早餐、11–14 午餐、17–20 晚餐、其余加餐', () {
      expect(MealType.forHour(6), MealType.breakfast);
      expect(MealType.forHour(10), MealType.breakfast);
      expect(MealType.forHour(11), MealType.lunch);
      expect(MealType.forHour(14), MealType.lunch);
      expect(MealType.forHour(17), MealType.dinner);
      expect(MealType.forHour(20), MealType.dinner);
      for (final h in [0, 5, 15, 16, 21, 23]) {
        expect(MealType.forHour(h), MealType.snack, reason: '$h 点应为加餐');
      }
    });
  });

  group('汇总与分组', () {
    CalorieEntry entry({
      required int id,
      required MealType meal,
      int kcal = 100,
      double p = 0,
      double c = 0,
      double f = 0,
      int minute = 0,
      DateTime? deleted,
    }) => CalorieEntry(
      id: id,
      date: DateTime(2026, 10, 18),
      meal: meal,
      name: '食物$id',
      kcal: kcal,
      proteinG: p,
      carbG: c,
      fatG: f,
      createdAt: DateTime(2026, 10, 18, 8, minute),
      deletedAt: deleted,
    );

    test('CalorieTotals.of 累加四项，已删除不计', () {
      final totals = CalorieTotals.of([
        entry(id: 1, meal: MealType.breakfast, kcal: 300, p: 10, c: 40, f: 5),
        entry(id: 2, meal: MealType.lunch, kcal: 500, p: 20, c: 60, f: 15),
      ]);
      expect(totals.kcalInt, 800);
      expect(totals.proteinG, 30);
      expect(totals.carbG, 100);
      expect(totals.fatG, 20);
    });

    test('groupByMeal 按早/午/晚/加餐顺序，空餐次不产出分组', () {
      final groups = groupByMeal([
        entry(id: 1, meal: MealType.dinner, kcal: 600),
        entry(id: 2, meal: MealType.breakfast, kcal: 300),
        entry(id: 3, meal: MealType.breakfast, kcal: 200, minute: 10),
        entry(id: 4, meal: MealType.snack, kcal: 100, deleted: DateTime(2026)),
      ]);
      expect(groups.map((g) => g.meal), [
        MealType.breakfast,
        MealType.dinner,
      ]);
      expect(groups.first.entries.length, 2);
      expect(groups.first.subtotal.kcalInt, 500);
    });
  });

  group('目标热量（Mifflin-St Jeor）', () {
    test('男：10×kg + 6.25×cm − 5×age + 5', () {
      // 70kg / 175cm / 30 岁 → 700 + 1093.75 − 150 + 5 = 1648.75
      final bmr = targetCalories(
        sex: CalorieSex.male,
        weightKg: 70,
        heightCm: 175,
        age: 30,
        activityFactor: 1,
      );
      expect(bmr, 1649);
    });

    test('女：末项 −161（比同条件男性少 166）', () {
      final male = targetCalories(
        sex: CalorieSex.male,
        weightKg: 55,
        heightCm: 162,
        age: 28,
        activityFactor: 1,
      )!;
      final female = targetCalories(
        sex: CalorieSex.female,
        weightKg: 55,
        heightCm: 162,
        age: 28,
        activityFactor: 1,
      )!;
      expect(male - female, 166);
    });

    test('活动系数线性放大', () {
      int? at(double f) => targetCalories(
        sex: CalorieSex.male,
        weightKg: 70,
        heightCm: 175,
        age: 30,
        activityFactor: f,
      );
      expect(at(1.2), (1648.75 * 1.2).round());
      expect(at(1.725), (1648.75 * 1.725).round());
    });

    test('非法输入返回 null（不编数字）', () {
      expect(
        targetCalories(
          sex: CalorieSex.male,
          weightKg: 0,
          heightCm: 175,
          age: 30,
          activityFactor: 1.2,
        ),
        isNull,
      );
      expect(
        targetCalories(
          sex: CalorieSex.male,
          weightKg: 70,
          heightCm: 175,
          age: 0,
          activityFactor: 1.2,
        ),
        isNull,
      );
    });
  });

  group('CalorieRepositoryImpl（内存 SQLite）', () {
    late AppDatabase db;
    late CalorieRepositoryImpl repo;
    final today = DateTime(2026, 10, 18, 15, 30);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = CalorieRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('只返回当天记录（时间部分忽略），按创建顺序', () async {
      await repo.add(date: today, meal: MealType.lunch, name: 'A', kcal: 300);
      await repo.add(
        date: DateTime(2026, 10, 17, 9),
        meal: MealType.lunch,
        name: 'B',
        kcal: 400,
      );
      final rows = await repo.watchByDate(today).first;
      expect(rows.map((e) => e.name), ['A']);
    });

    test('名字为空或热量 ≤ 0 不落库', () async {
      expect(
        await repo.add(date: today, meal: MealType.lunch, name: ' ', kcal: 300),
        isNull,
      );
      expect(
        await repo.add(date: today, meal: MealType.lunch, name: 'X', kcal: 0),
        isNull,
      );
      expect(await repo.watchByDate(today).first, isEmpty);
    });

    test('营养四项默认 0，可写入小数', () async {
      await repo.add(
        date: today,
        meal: MealType.breakfast,
        name: '牛奶',
        kcal: 120,
        proteinG: 7.5,
        carbG: 9.6,
        fatG: 3.2,
      );
      final e = (await repo.watchByDate(today).first).single;
      expect(e.meal, MealType.breakfast);
      expect(e.proteinG, 7.5);
      expect(e.carbG, 9.6);
      expect(e.fatG, 3.2);
    });

    test('软删除 + 撤销', () async {
      final id = (await repo.add(
        date: today,
        meal: MealType.dinner,
        name: '米饭',
        kcal: 200,
      ))!;
      await repo.softDelete(id);
      expect(await repo.watchByDate(today).first, isEmpty);
      await repo.restore(id);
      expect(await repo.watchByDate(today).first, hasLength(1));
    });

    test('recentNames 去重且最近用过的排前面', () async {
      await repo.add(date: today, meal: MealType.lunch, name: '米饭', kcal: 200);
      await repo.add(date: today, meal: MealType.lunch, name: '鸡胸肉', kcal: 150);
      await repo.add(date: today, meal: MealType.dinner, name: '米饭', kcal: 250);

      final names = await repo.recentNames();
      expect(names.toSet(), {'米饭', '鸡胸肉'});
      expect(names.first, '米饭', reason: '最后一次使用最晚 → 排最前');
    });
  });
}
