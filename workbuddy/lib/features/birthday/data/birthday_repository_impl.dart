import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/birthday.dart';
import '../domain/birthday_repository.dart';

/// 生日仓库的 Drift 实现。
class BirthdayRepositoryImpl implements BirthdayRepository {
  BirthdayRepositoryImpl(this._db);

  final db.AppDatabase _db;

  Birthday _toDomain(db.Birthday row) => Birthday(
    id: row.id,
    name: row.name,
    birthdayYear: row.birthdayYear,
    month: row.birthdayMonth,
    day: row.birthdayDay,
    calendar: BirthdayCalendar.byId(row.calendarType),
    groupTag: row.groupTag,
    advanceDays: row.advanceDays,
    notes: row.notes,
    createdAt: row.createdAt,
    deletedAt: row.deletedAt,
  );

  SimpleSelectStatement<db.$BirthdaysTable, db.Birthday> _alive() {
    return _db.select(_db.birthdays)..where((t) => t.deletedAt.isNull());
  }

  @override
  Stream<List<Birthday>> watchAll() {
    final query = _alive()
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.watch().map((rows) => [for (final r in rows) _toDomain(r)]);
  }

  @override
  Future<List<Birthday>> all() async {
    final rows = await _alive().get();
    return [for (final r in rows) _toDomain(r)];
  }

  @override
  Future<Birthday?> findById(int id) async {
    final row = await (_db.select(
      _db.birthdays,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<int?> create({
    required String name,
    required int month,
    required int day,
    required BirthdayCalendar calendar,
    int? year,
    String? groupTag,
    int advanceDays = 3,
    String? notes,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    return _db.into(_db.birthdays).insert(
      db.BirthdaysCompanion.insert(
        name: n,
        birthdayMonth: month,
        birthdayDay: day,
        calendarType: Value(calendar.id),
        birthdayYear: Value(year),
        groupTag: Value(_emptyToNull(groupTag)),
        advanceDays: Value(advanceDays < 0 ? 0 : advanceDays),
        notes: Value(_emptyToNull(notes)),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> update(
    int id, {
    String? name,
    int? month,
    int? day,
    BirthdayCalendar? calendar,
    int? year,
    bool clearYear = false,
    String? groupTag,
    bool clearGroupTag = false,
    int? advanceDays,
    String? notes,
    bool clearNotes = false,
  }) {
    return (_db.update(_db.birthdays)..where((t) => t.id.equals(id))).write(
      db.BirthdaysCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        birthdayMonth: Value.absentIfNull(month),
        birthdayDay: Value.absentIfNull(day),
        calendarType: Value.absentIfNull(calendar?.id),
        birthdayYear: clearYear
            ? const Value(null)
            : Value.absentIfNull(year),
        groupTag: clearGroupTag
            ? const Value(null)
            : Value.absentIfNull(_emptyToNull(groupTag)),
        advanceDays: Value.absentIfNull(advanceDays),
        notes: clearNotes
            ? const Value(null)
            : Value.absentIfNull(_emptyToNull(notes)),
      ),
    );
  }

  @override
  Future<void> softDelete(int id) {
    return (_db.update(_db.birthdays)..where((t) => t.id.equals(id))).write(
      db.BirthdaysCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> restore(int id) {
    return (_db.update(_db.birthdays)..where((t) => t.id.equals(id))).write(
      const db.BirthdaysCompanion(deletedAt: Value(null)),
    );
  }

  static String? _emptyToNull(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
