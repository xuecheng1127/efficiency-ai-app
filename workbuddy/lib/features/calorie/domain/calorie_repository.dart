import 'calorie.dart';

/// 热量记录仓库。
abstract interface class CalorieRepository {
  /// 某一天的全部记录（未删除）。
  Stream<List<CalorieEntry>> watchByDate(DateTime date);

  /// 新增一条。名字为空 / 热量 ≤ 0 不落库（返回 null）。
  Future<int?> add({
    required DateTime date,
    required MealType meal,
    required String name,
    required int kcal,
    double proteinG = 0,
    double carbG = 0,
    double fatG = 0,
  });

  Future<void> softDelete(int id);

  Future<void> restore(int id);

  /// 历史食物名（去重、按最近使用排序）——给「输入食物名给历史联想」用。
  Future<List<String>> recentNames({int limit = 20});
}
