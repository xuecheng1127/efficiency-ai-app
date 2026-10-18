import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/diary_entry.dart';
import '../domain/diary_repository.dart';

/// 日记仓库的 Drift 实现。
///
/// 只做持久化；排版与渲染在 `engine/cjk_layout.dart` 与 presentation 层。
class DiaryRepositoryImpl implements DiaryRepository {
  DiaryRepositoryImpl(this._db);

  final AppDatabase _db;

  /// Drift 行 → 纯 Dart 实体（Domain 不依赖 ORM 的边界就在这一行）。
  DiaryEntry _toDomain(Diary row) => DiaryEntry(
    id: row.id,
    title: row.title,
    content: row.content,
    templateType: row.templateType,
    fontSize: row.fontSize,
    fontFamily: row.fontFamily,
    coverPath: row.coverPath,
    diaryDate: row.diaryDate,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );

  SimpleSelectStatement<$DiariesTable, Diary> _aliveQuery() {
    return _db.select(_db.diaries)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.diaryDate),
        (t) => OrderingTerm.desc(t.updatedAt),
        // 兜底：DateTime 在 Drift 里默认存秒级时间戳，同一天同一秒建的两篇会打平，
        // 用 id 倒序保证「后建的排前面」稳定成立。
        (t) => OrderingTerm.desc(t.id),
      ]);
  }

  @override
  Stream<List<DiaryEntry>> watchAll() {
    return _aliveQuery().watch().map(
      (rows) => [for (final r in rows) _toDomain(r)],
    );
  }

  @override
  Future<List<DiaryEntry>> search(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) {
      final rows = await _aliveQuery().get();
      return [for (final r in rows) _toDomain(r)];
    }
    // 转义 LIKE 的通配符，避免用户输入 % 时把整库捞出来
    final escaped = k
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows =
        await (_db.select(_db.diaries)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    (t.title.like('%$escaped%') | t.content.like('%$escaped%')),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.diaryDate),
                (t) => OrderingTerm.desc(t.updatedAt),
                (t) => OrderingTerm.desc(t.id),
              ]))
            .get();
    return [for (final r in rows) _toDomain(r)];
  }

  @override
  Future<DiaryEntry?> findById(int id) async {
    final row = await (_db.select(
      _db.diaries,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<int> create({
    required String title,
    required String content,
    required String templateType,
    required double fontSize,
    String? fontFamily,
    DateTime? diaryDate,
  }) {
    final now = DateTime.now();
    // 规格 §2：`diary_date` 存「当天 0 点」。传进来的时间一律截断到日，
    // 否则同一天写两篇会分成两个日期桶，列表分组就错乱了。
    final at = diaryDate ?? now;
    final day = DateTime(at.year, at.month, at.day);
    return _db
        .into(_db.diaries)
        .insert(
          DiariesCompanion.insert(
            diaryDate: day,
            createdAt: now,
            updatedAt: now,
            title: Value(title),
            content: Value(content),
            templateType: Value(templateType),
            fontSize: Value(fontSize),
            fontFamily: Value(fontFamily),
          ),
        );
  }

  @override
  Future<void> update(
    int id, {
    String? title,
    String? content,
    String? templateType,
    double? fontSize,
    String? fontFamily,
    String? coverPath,
  }) async {
    await (_db.update(_db.diaries)..where((t) => t.id.equals(id))).write(
      DiariesCompanion(
        title: title == null ? const Value.absent() : Value(title),
        content: content == null ? const Value.absent() : Value(content),
        templateType: templateType == null
            ? const Value.absent()
            : Value(templateType),
        fontSize: fontSize == null ? const Value.absent() : Value(fontSize),
        fontFamily: fontFamily == null
            ? const Value.absent()
            : Value(fontFamily),
        coverPath: coverPath == null ? const Value.absent() : Value(coverPath),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> softDelete(int id) async {
    await (_db.update(_db.diaries)..where((t) => t.id.equals(id))).write(
      DiariesCompanion(deletedAt: Value(DateTime.now())),
    );
  }
}
