import 'package:drift/drift.dart';

/// 热量记录（模块2 插件 · 规格：calorie_entries）。
///
/// 一行 = 一次进食（不是一个食物库）。营养四项都允许 0：
/// 用户只记热量时不强迫填蛋白/碳水/脂肪。
class CalorieEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 归属日（当天 0 点，与任务/日记一致：按本地日期比较）
  DateTimeColumn get entryDate => dateTime()();

  /// `breakfast` / `lunch` / `dinner` / `snack`
  TextColumn get meal => text()();

  /// 食物名（用户原文，用于历史联想）
  TextColumn get name => text()();

  IntColumn get kcal => integer()();

  RealColumn get proteinG => real().withDefault(const Constant(0))();

  RealColumn get carbG => real().withDefault(const Constant(0))();

  RealColumn get fatG => real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}
