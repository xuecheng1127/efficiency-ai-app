import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
// Drift 按表名 `Memos` 生成了一个同名行类 `Memo`，与领域实体 `Memo` 冲突。
// 这里给领域实体加前缀，数据库层保持不带前缀（读起来更清楚哪个是 row）。
import '../domain/memo.dart' as domain;
import '../domain/memo_repository.dart';

/// 备忘仓库的 Drift 实现（T23 规格 §2 的表结构，字段一一对应）。
class MemoRepositoryImpl implements MemoRepository {
  MemoRepositoryImpl(this._db);

  final AppDatabase _db;

  domain.Memo _toDomain(Memo row) => domain.Memo(
    id: row.id,
    content: row.content,
    pinned: row.pinned,
    color: row.color,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );

  /// 排序口径（规格 §3.1）：**置顶排最前**，组内按更新时间倒序。
  ///
  /// SQLite 里 boolean 就是 0/1，`ORDER BY pinned DESC` 天然把 1 排前面。
  SimpleSelectStatement<$MemosTable, Memo> _aliveQuery() {
    return _db.select(_db.memos)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.pinned),
        (t) => OrderingTerm.desc(t.updatedAt),
        // 兜底：Drift 默认把 DateTime 存成**秒级**时间戳，同一秒内建的两条备忘
        // updatedAt 完全相同，只靠 updatedAt 排序结果不稳定（实测会出现 1 在 2 前面）。
        // 加 id 倒序让"后来建的排前面"这条直觉始终成立。
        (t) => OrderingTerm.desc(t.id),
      ]);
  }

  @override
  Stream<List<domain.Memo>> watchAll() {
    return _aliveQuery().watch().map(
      (rows) => [for (final r in rows) _toDomain(r)],
    );
  }

  @override
  Future<domain.Memo?> findById(int id) async {
    final row = await (_db.select(
      _db.memos,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<int> create({
    required String content,
    bool pinned = false,
    String? color,
  }) {
    final now = DateTime.now();
    return _db
        .into(_db.memos)
        .insert(
          MemosCompanion.insert(
            content: content,
            createdAt: now,
            updatedAt: now,
            pinned: Value(pinned),
            color: Value(color),
          ),
        );
  }

  @override
  Future<void> update(
    int id, {
    String? content,
    bool? pinned,
    String? color,
  }) async {
    await (_db.update(_db.memos)..where((t) => t.id.equals(id))).write(
      MemosCompanion(
        content: content == null ? const Value.absent() : Value(content),
        pinned: pinned == null ? const Value.absent() : Value(pinned),
        color: color == null ? const Value.absent() : Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> setPinned(int id, bool pinned) async {
    await (_db.update(_db.memos)..where((t) => t.id.equals(id))).write(
      MemosCompanion(pinned: Value(pinned), updatedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> softDelete(int id) async {
    await (_db.update(_db.memos)..where((t) => t.id.equals(id))).write(
      MemosCompanion(deletedAt: Value(DateTime.now())),
    );
  }
}
