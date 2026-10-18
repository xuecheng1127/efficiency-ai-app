import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/diary/data/diary_repository_impl.dart';
import 'package:efficiency_app/features/diary/domain/diary_entry.dart';

/// T22 · 日记仓库（内存 SQLite）
void main() {
  group('DiaryRepository（内存 SQLite）', () {
    late AppDatabase db;
    late DiaryRepositoryImpl repo;

    final today = DateTime(2026, 10, 18);
    final yesterday = DateTime(2026, 10, 17);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DiaryRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('创建后能按 id 读回，字段一一对应', () async {
      final id = await repo.create(
        title: '标题',
        content: '正文第一行\n第二行',
        templateType: DiaryTemplateType.blank,
        fontSize: 20,
      );
      final e = await repo.findById(id);
      expect(e, isNotNull);
      expect(e!.title, '标题');
      expect(e.content, '正文第一行\n第二行');
      expect(e.templateType, DiaryTemplateType.blank);
      expect(e.fontSize, 20);
      expect(e.deletedAt, isNull);
    });

    test('diaryDate 落在当天 0 点（按日归档的前提）', () async {
      final id = await repo.create(
        title: '',
        content: 'x',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
        diaryDate: DateTime(2026, 10, 18, 23, 59),
      );
      final e = await repo.findById(id);
      expect(e!.diaryDate, DateTime(2026, 10, 18));
    });

    test('update 只改传进来的字段，其余保持', () async {
      final id = await repo.create(
        title: '旧标题',
        content: '旧正文',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
      );
      await repo.update(id, content: '新正文');
      final e = await repo.findById(id);
      expect(e!.content, '新正文');
      expect(e.title, '旧标题', reason: '没传 title 就不该被清空');
      expect(e.fontSize, 16);
    });

    test('watchAll 按日期倒序：今天在昨天之前', () async {
      final a = await repo.create(
        title: '昨天',
        content: 'a',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
        diaryDate: yesterday,
      );
      final b = await repo.create(
        title: '今天',
        content: 'b',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
        diaryDate: today,
      );
      final rows = await repo.watchAll().first;
      expect(rows.map((e) => e.id).toList(), [b, a]);
    });

    test('软删除后 watchAll / findById 都查不到（重启不复活）', () async {
      final id = await repo.create(
        title: '待删',
        content: 'x',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
      );
      await repo.softDelete(id);
      expect(await repo.findById(id), isNull);
      expect((await repo.watchAll().first).where((e) => e.id == id), isEmpty);

      // 行还在表里（软删除），deletedAt 有值
      final raw = await (db.select(
        db.diaries,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(raw.deletedAt, isNotNull);
    });

    test('搜索命中标题或正文，且过滤软删除', () async {
      await repo.create(
        title: '去海边',
        content: '风很大',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
      );
      final hitByBody = await repo.create(
        title: '随便',
        content: '海边捡到一块石头',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
      );
      final deleted = await repo.create(
        title: '海边',
        content: '删掉的那条',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
      );
      await repo.softDelete(deleted);

      final result = await repo.search('海边');
      expect(result.map((e) => e.id).toSet(), {1, hitByBody});
      expect(result.length, 2);
    });

    test('搜索里的 % 与 _ 被转义，不会把整库捞出来', () async {
      await repo.create(
        title: '普通',
        content: '没有通配符',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
      );
      final result = await repo.search('%');
      expect(result, isEmpty);
    });

    test('图片只存相对路径：coverPath 写入的是 diary_media/...', () async {
      final id = await repo.create(
        title: '',
        content: '[[img:diary_media/a.jpg]]',
        templateType: DiaryTemplateType.lined,
        fontSize: 16,
      );
      await repo.update(id, coverPath: 'diary_media/a.jpg');
      final e = await repo.findById(id);
      expect(e!.coverPath, 'diary_media/a.jpg');
      expect(e.coverPath!.startsWith('/'), isFalse);
      expect(e.coverPath!.contains(':\\'), isFalse);
    });
  });
}
