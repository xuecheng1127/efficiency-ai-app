import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/calorie.dart';
import '../domain/calorie_repository.dart';

/// 热量仓库的 Drift 实现。
class CalorieRepositoryImpl implements CalorieRepository {
  CalorieRepositoryImpl(this._db);

  final db.AppDatabase _db;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  CalorieEntry _toDomain(db.CalorieEntry row) => CalorieEntry(
    id: row.id,
    date: row.entryDate,
    meal: MealType.byId(row.meal),
    name: row.name,
    kcal: row.kcal,
    proteinG: row.proteinG,
    carbG: row.carbG,
    fatG: row.fatG,
    createdAt: row.createdAt,
    deletedAt: row.deletedAt,
  );

  @override
  Stream<List<CalorieEntry>> watchByDate(DateTime date) {
    final day = dateOnly(date);
    final query = _db.select(_db.calorieEntries)
      ..where((t) => t.deletedAt.isNull() & t.entryDate.equals(day))
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return query.watch().map(
      (rows) => [for (final r in rows) _toDomain(r)],
    );
  }

  @override
  Future<int?> add({
    required DateTime date,
    required MealType meal,
    required String name,
    required int kcal,
    double proteinG = 0,
    double carbG = 0,
    double fatG = 0,
  }) async {
    final n = name.trim();
    if (n.isEmpty || kcal <= 0) return null;
    return _db.into(_db.calorieEntries).insert(
      db.CalorieEntriesCompanion.insert(
        entryDate: dateOnly(date),
        meal: meal.id,
        name: n,
        kcal: kcal,
        proteinG: Value(proteinG < 0 ? 0 : proteinG),
        carbG: Value(carbG < 0 ? 0 : carbG),
        fatG: Value(fatG < 0 ? 0 : fatG),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> softDelete(int id) {
    return (_db.update(_db.calorieEntries)..where((t) => t.id.equals(id)))
        .write(db.CalorieEntriesCompanion(deletedAt: Value(DateTime.now())));
  }

  @override
  Future<void> restore(int id) {
    return (_db.update(_db.calorieEntries)..where((t) => t.id.equals(id)))
        .write(const db.CalorieEntriesCompanion(deletedAt: Value(null)));
  }

  /// 最近用过的食物名：**去重后按最后一次使用时间倒序**。
  ///
  /// 用原生 SQL 是因为 Drift 的表达能力在这里要绕：需要「按 name 分组取最大 id」。
  @override
  Future<List<String>> recentNames({int limit = 20}) async {
    final rows = await _db.customSelect(
      'SELECT name, MAX(id) AS last_id FROM calorie_entries '
      'WHERE deleted_at IS NULL GROUP BY name ORDER BY last_id DESC LIMIT ?',
      variables: [Variable<int>(limit)],
    ).get();
    return [for (final r in rows) r.read<String>('name')];
  }
}
