import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';

class CalorieRepository {
  final AppDatabase db;
  CalorieRepository(this.db);

  int get todayKey {
    final n = DateTime.now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  Stream<List<CalorieEntryRow>> watchToday() {
    return (db.select(db.calorieEntries)
          ..where((t) => t.entryDate.equals(todayKey) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<int> add({
    required String name,
    required int kcal,
    required String meal,
    double protein = 0,
    double carb = 0,
    double fat = 0,
  }) {
    return db.into(db.calorieEntries).insert(
          CalorieEntriesCompanion.insert(
            entryDate: todayKey,
            meal: meal,
            name: name,
            kcal: kcal,
            proteinG: Value(protein),
            carbG: Value(carb),
            fatG: Value(fat),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> softDelete(int id) async {
    await (db.update(db.calorieEntries)..where((t) => t.id.equals(id)))
        .write(CalorieEntriesCompanion(
      deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// 历史食物名（去重，用于联想）
  Future<List<String>> historyNames(String prefix) async {
    final rows = await (db.select(db.calorieEntries)
          ..where((t) => t.deletedAt.isNull() & t.name.like('%$prefix%'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(10))
        .get();
    return rows.map((r) => r.name).toSet().toList();
  }

  /// 目标 kcal
  Future<int> getTarget() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('calorie_target') ?? 2000;
  }

  Future<void> setTarget(int kcal) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('calorie_target', kcal);
  }

  /// Mifflin-St Jeor
  static double bmr({
    required String gender,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return gender == 'male' ? base + 5 : base - 161;
  }

  /// 按当前时间自动选餐次
  static String autoMeal() {
    final h = DateTime.now().hour;
    if (h >= 6 && h < 10) return 'breakfast';
    if (h >= 11 && h < 14) return 'lunch';
    if (h >= 17 && h < 20) return 'dinner';
    return 'snack';
  }

  static String mealLabel(String m) {
    switch (m) {
      case 'breakfast': return '早餐';
      case 'lunch': return '午餐';
      case 'dinner': return '晚餐';
      default: return '加餐';
    }
  }
}
