import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/diaries.dart';

/// 日记仓库（T22）
class DiaryRepository {
  final AppDatabase _db;
  DiaryRepository(this._db);

  /// 按日期倒序监听全部未删除日记
  Stream<List<DiaryRow>> watchAll() {
    return (_db.select(_db.diaries)
          ..where((d) => d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm.desc(d.diaryDate)]))
        .watch();
  }

  /// 按 id 取一条
  Future<DiaryRow?> getById(int id) {
    return (_db.select(_db.diaries)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
  }

  /// 新建或更新（有 id 更新，无 id 插入）
  Future<int> upsert({
    int? id,
    String title = '',
    String content = '',
    String templateType = 'lined',
    double fontSize = 16.0,
    required int diaryDate,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id != null) {
      await (_db.update(_db.diaries)..where((d) => d.id.equals(id))).write(
        DiariesCompanion(
          title: Value(title),
          content: Value(content),
          templateType: Value(templateType),
          fontSize: Value(fontSize),
          updatedAt: Value(now),
        ),
      );
      return id;
    }
    return _db.into(_db.diaries).insert(
          DiariesCompanion.insert(
            title: Value(title),
            content: Value(content),
            templateType: Value(templateType),
            fontSize: Value(fontSize),
            diaryDate: diaryDate,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// 软删除
  Future<void> softDelete(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.diaries)..where((d) => d.id.equals(id)))
        .write(DiariesCompanion(deletedAt: Value(now)));
  }
}
