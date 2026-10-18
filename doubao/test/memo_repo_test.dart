import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/toolbox/data/memo_repository.dart';

void main() {
  late AppDatabase db;
  late MemoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MemoRepository(db);
  });

  tearDown(() => db.close());

  test('M1 新建备忘后立刻可查到', () async {
    final id = await repo.upsert(content: '买牛奶');
    expect(id, greaterThan(0));
    final rows = await repo.watchAll().first;
    expect(rows.length, 1);
    expect(rows.first.content, '买牛奶');
  });

  test('M2 编辑后备忘内容更新', () async {
    final id = await repo.upsert(content: '原文');
    await repo.upsert(id: id, content: '改后');
    final rows = await repo.watchAll().first;
    expect(rows.single.content, '改后');
  });

  test('M3 删除后备忘消失，且不复活', () async {
    final id = await repo.upsert(content: '待删');
    await repo.softDelete(id);
    var rows = await repo.watchAll().first;
    expect(rows, isEmpty);
    // 再查一次，确认不会复活
    rows = await repo.watchAll().first;
    expect(rows, isEmpty);
  });

  test('M4 置顶排最前', () async {
    await repo.upsert(content: '普通A');
    await repo.upsert(content: '置顶B', pinned: true);
    await repo.upsert(content: '普通C');
    final rows = await repo.watchAll().first;
    expect(rows.length, 3);
    expect(rows.first.pinned, 1);
    expect(rows.first.content, '置顶B');
  });

  test('M5 软删除不影响其他备忘', () async {
    final id1 = await repo.upsert(content: '保留');
    await repo.upsert(content: '要删');
    await repo.softDelete(id1);
    final rows = await repo.watchAll().first;
    expect(rows.length, 1);
    expect(rows.single.content, '要删');
  });
}
