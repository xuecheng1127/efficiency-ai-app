import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/core/database/app_database.dart' hide Memo;
import 'package:efficiency_app/features/memo/data/memo_repository_impl.dart';
import 'package:efficiency_app/features/memo/domain/memo.dart';
import 'package:efficiency_app/features/memo/providers/memo_providers.dart';

/// T23 · 备忘录 CRUD（内存 SQLite）
void main() {
  group('MemoRepository（内存 SQLite）', () {
    late AppDatabase db;
    late MemoRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = MemoRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('C：新建后立刻能读到（内容原样，含换行）', () async {
      final id = await repo.create(content: '第一行\n第二行');
      final memo = await repo.findById(id);
      expect(memo, isNotNull);
      expect(memo!.content, '第一行\n第二行');
      expect(memo.pinned, isFalse);
      expect(memo.deletedAt, isNull);
    });

    test('R：watchAll 置顶排最前，组内按更新时间倒序', () async {
      final a = await repo.create(content: '普通 A');
      final b = await repo.create(content: '普通 B');
      final c = await repo.create(content: '置顶 C');
      await repo.setPinned(c, true);

      final rows = await repo.watchAll().first;
      expect(rows.first.id, c, reason: '置顶必须排最前');
      expect(rows.map((m) => m.id).toList(), [c, b, a]);
    });

    test('U：编辑内容后 updatedAt 变化，置顶态保留', () async {
      final id = await repo.create(content: '旧内容', pinned: true);
      final before = await repo.findById(id);
      // Drift 默认把 DateTime 存成**秒级**时间戳，必须跨过整秒边界才能观察到
      // updatedAt 变化（这不是 bug，是存储精度；顺序问题已由 id 兜底排序解决）。
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await repo.update(id, content: '新内容');
      final after = await repo.findById(id);
      expect(after!.content, '新内容');
      expect(after.pinned, isTrue, reason: '没传 pinned 就不该被改');
      expect(after.updatedAt.isAfter(before!.updatedAt), isTrue);
    });

    test('D：软删除后查不到，且行仍在表里（重启不复活）', () async {
      final id = await repo.create(content: '要删的');
      await repo.softDelete(id);
      expect(await repo.findById(id), isNull);
      expect((await repo.watchAll().first).where((m) => m.id == id), isEmpty);

      final raw = await (db.select(
        db.memos,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(raw.deletedAt, isNotNull);
    });

    test('置顶切换：setPinned(true/false) 双向可用', () async {
      final id = await repo.create(content: 'x');
      await repo.setPinned(id, true);
      expect((await repo.findById(id))!.pinned, isTrue);
      await repo.setPinned(id, false);
      expect((await repo.findById(id))!.pinned, isFalse);
    });

    test('纸色可存可取（null = 默认）', () async {
      final id = await repo.create(content: '黄色便利贴', color: MemoColor.yellow);
      expect((await repo.findById(id))!.color, MemoColor.yellow);
      final plain = await repo.create(content: '默认纸色');
      expect((await repo.findById(plain))!.color, isNull);
    });

    test('搜索：按内容过滤，大小写不敏感，不命中软删除的', () async {
      await repo.create(content: '买牛奶');
      await repo.create(content: 'MILK 也要');
      final deleted = await repo.create(content: '牛奶 但删了');
      await repo.softDelete(deleted);
      await repo.create(content: '无关内容');

      final live = await repo.watchAll().first;
      final hit = MemoSearchNotifier.filter(live, 'milk');
      expect(hit.length, 1);
      expect(hit.single.content, 'MILK 也要');

      final cn = MemoSearchNotifier.filter(live, '牛奶');
      expect(cn.length, 1);
      expect(cn.single.content, '买牛奶');
    });

    test('空关键词返回全部；空列表不崩', () {
      expect(MemoSearchNotifier.filter(const [], 'x'), isEmpty);
      final one = [
        Memo(
          id: 1,
          content: 'a',
          pinned: false,
          color: null,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
      expect(MemoSearchNotifier.filter(one, '  ').length, 1);
    });
  });

  group('Memo 实体', () {
    test('summary 压平换行并截断', () {
      final memo = Memo(
        id: 1,
        content: '第一行\n\n  第二行',
        pinned: false,
        color: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(memo.summary(), '第一行 第二行');
    });

    test('firstLine 取第一个非空行（编辑页标题用）', () {
      final memo = Memo(
        id: 1,
        content: '\n\n  标题行  \n正文',
        pinned: false,
        color: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(memo.firstLine, '标题行');
    });
  });
}
