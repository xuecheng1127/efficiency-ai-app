/// ============================================================================
/// 每日热量：餐次、汇总、目标公式（**纯 Dart**）
/// ============================================================================
///
/// 目标热量用 Mifflin-St Jeor + 活动系数（不引入任何第三方公式库）：
/// 男：10×kg + 6.25×cm − 5×age + 5
/// 女：10×kg + 6.25×cm − 5×age − 161
/// 目标 = BMR × 活动系数（1.2 / 1.375 / 1.55 / 1.725）
library;

/// 餐次。`id` 落库，`label` 显示。
enum MealType {
  breakfast(id: 'breakfast', label: '早餐'),
  lunch(id: 'lunch', label: '午餐'),
  dinner(id: 'dinner', label: '晚餐'),
  snack(id: 'snack', label: '加餐');

  const MealType({required this.id, required this.label});

  final String id;
  final String label;

  static MealType byId(String? id) {
    for (final m in MealType.values) {
      if (m.id == id) return m;
    }
    return MealType.snack;
  }

  /// 按时间自动选餐次（规格：6–10 早 / 11–14 午 / 17–20 晚 / 其它加餐）。
  ///
  /// 边界取「闭区间」：10:59 仍是早餐、14:59 仍是午餐、20:59 仍是晚餐 ——
  /// 用户的直觉是「这个时段吃的算这一餐」，而不是精确到整点。
  static MealType forHour(int hour) {
    if (hour >= 6 && hour <= 10) return MealType.breakfast;
    if (hour >= 11 && hour <= 14) return MealType.lunch;
    if (hour >= 17 && hour <= 20) return MealType.dinner;
    return MealType.snack;
  }

  /// 一天里的展示顺序（不按 id 字母序）。
  int get order => switch (this) {
    MealType.breakfast => 0,
    MealType.lunch => 1,
    MealType.dinner => 2,
    MealType.snack => 3,
  };
}

/// 一条热量记录（映射 `calorie_entries`）。
class CalorieEntry {
  const CalorieEntry({
    required this.id,
    required this.date,
    required this.meal,
    required this.name,
    required this.kcal,
    this.proteinG = 0,
    this.carbG = 0,
    this.fatG = 0,
    required this.createdAt,
    this.deletedAt,
  });

  final int id;
  final DateTime date;
  final MealType meal;
  final String name;
  final int kcal;
  final double proteinG;
  final double carbG;
  final double fatG;
  final DateTime createdAt;
  final DateTime? deletedAt;
}

/// 营养汇总（克 / 千卡）。
class CalorieTotals {
  const CalorieTotals({
    this.kcal = 0,
    this.proteinG = 0,
    this.carbG = 0,
    this.fatG = 0,
  });

  final double kcal;
  final double proteinG;
  final double carbG;
  final double fatG;

  CalorieTotals operator +(CalorieEntry e) => CalorieTotals(
    kcal: kcal + e.kcal,
    proteinG: proteinG + e.proteinG,
    carbG: carbG + e.carbG,
    fatG: fatG + e.fatG,
  );

  static CalorieTotals of(Iterable<CalorieEntry> entries) {
    var t = const CalorieTotals();
    for (final e in entries) {
      t = t + e;
    }
    return t;
  }

  int get kcalInt => kcal.round();
}

/// 按餐次分组（组内按创建时间正序：先吃的在前）。
class MealGroup {
  const MealGroup({required this.meal, required this.entries});

  final MealType meal;
  final List<CalorieEntry> entries;

  CalorieTotals get subtotal => CalorieTotals.of(entries);
}

List<MealGroup> groupByMeal(List<CalorieEntry> entries) {
  final alive = entries.where((e) => e.deletedAt == null).toList();
  final out = <MealGroup>[];
  for (final meal in MealType.values.toList()
    ..sort((a, b) => a.order.compareTo(b.order))) {
    final list = alive.where((e) => e.meal == meal).toList()
      ..sort((a, b) {
        final c = a.createdAt.compareTo(b.createdAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    if (list.isNotEmpty) out.add(MealGroup(meal: meal, entries: list));
  }
  return out;
}

/// 性别（只影响 BMR 常数项）。
enum CalorieSex {
  male(id: 'male', label: '男', adjust: 5),
  female(id: 'female', label: '女', adjust: -161);

  const CalorieSex({required this.id, required this.label, required this.adjust});

  final String id;
  final String label;

  /// Mifflin-St Jeor 的性别常数项
  final double adjust;

  static CalorieSex byId(String? id) =>
      id == 'female' ? CalorieSex.female : CalorieSex.male;
}

/// 活动系数（规格给的 4 档）。
class ActivityLevel {
  const ActivityLevel({
    required this.factor,
    required this.label,
    required this.description,
  });

  final double factor;
  final String label;
  final String description;
}

const List<ActivityLevel> kActivityLevels = [
  ActivityLevel(factor: 1.2, label: '久坐', description: '几乎不运动，办公室为主'),
  ActivityLevel(factor: 1.375, label: '轻度', description: '每周 1–3 次轻量运动'),
  ActivityLevel(factor: 1.55, label: '中度', description: '每周 3–5 次运动'),
  ActivityLevel(factor: 1.725, label: '高强度', description: '每周 6–7 次或体力工作'),
];

/// 目标热量计算（**纯函数**，可单测）。
///
/// 参数非法（身高/体重/年龄 ≤ 0）时返回 null，由 UI 提示，不静默给个假数字。
int? targetCalories({
  required CalorieSex sex,
  required double weightKg,
  required double heightCm,
  required int age,
  required double activityFactor,
}) {
  if (weightKg <= 0 || heightCm <= 0 || age <= 0) return null;
  if (activityFactor <= 0) return null;
  final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + sex.adjust;
  if (bmr <= 0) return null;
  return (bmr * activityFactor).round();
}
