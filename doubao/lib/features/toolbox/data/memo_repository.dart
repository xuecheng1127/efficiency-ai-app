import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/memos.dart';

class MemoRepository {
  final AppDatabase _db;
  MemoRepository(this._db);

  Stream<List<MemoRow>> watchAll() {
    return (_db.select(_db.memos)
          ..where((m) => m.deletedAt.isNull())
          ..orderBy([
            (m) => OrderingTerm.desc(m.pinned),
            (m) => OrderingTerm.desc(m.updatedAt),
          ]))
        .watch();
  }

  Future<int> upsert({int? id, required String content, bool pinned = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id != null) {
      await (_db.update(_db.memos)..where((m) => m.id.equals(id))).write(
        MemosCompanion(
          content: Value(content),
          pinned: Value(pinned ? 1 : 0),
          updatedAt: Value(now),
        ),
      );
      return id;
    }
    return _db.into(_db.memos).insert(
          MemosCompanion.insert(
            content: content,
            pinned: Value(pinned ? 1 : 0),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> softDelete(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.memos)..where((m) => m.id.equals(id)))
        .write(MemosCompanion(deletedAt: Value(now)));
  }
}
