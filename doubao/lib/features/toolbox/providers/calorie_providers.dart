import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/calorie_repository.dart';

final calorieRepoProvider = Provider((ref) => CalorieRepository(AppDatabase.instance));
final todayCaloriesProvider = StreamProvider((ref) => ref.watch(calorieRepoProvider).watchToday());
final calorieTargetProvider = FutureProvider((ref) => ref.watch(calorieRepoProvider).getTarget());
