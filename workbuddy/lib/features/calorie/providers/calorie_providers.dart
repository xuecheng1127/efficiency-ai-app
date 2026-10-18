import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/settings/app_settings.dart';
import '../data/calorie_repository_impl.dart';
import '../domain/calorie.dart';
import '../domain/calorie_repository.dart';

final calorieRepositoryProvider = Provider<CalorieRepository>((ref) {
  return CalorieRepositoryImpl(ref.watch(databaseProvider));
});

/// 今日记录（响应式：新增/删除立即反映）。
final todayCalorieEntriesProvider = StreamProvider<List<CalorieEntry>>((ref) {
  return ref.watch(calorieRepositoryProvider).watchByDate(DateTime.now());
});

final todayMealGroupsProvider = Provider<List<MealGroup>>((ref) {
  final entries =
      ref.watch(todayCalorieEntriesProvider).value ?? const <CalorieEntry>[];
  return groupByMeal(entries);
});

final todayCalorieTotalsProvider = Provider<CalorieTotals>((ref) {
  final entries =
      ref.watch(todayCalorieEntriesProvider).value ?? const <CalorieEntry>[];
  return CalorieTotals.of(entries);
});

/// 目标热量（设置里存的，单位 kcal）。
final calorieTargetProvider = Provider<int>((ref) {
  return ref.watch(appSettingsProvider).calorieTarget;
});

/// 历史食物名（输入联想）。今天的记录变了就重查一次，保证刚加的名字立刻能联想出来。
final foodHistoryProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(todayCalorieEntriesProvider);
  return ref.watch(calorieRepositoryProvider).recentNames();
});
