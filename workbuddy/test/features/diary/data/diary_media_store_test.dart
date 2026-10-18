import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:efficiency_app/features/diary/data/diary_media_store.dart';

/// T22 · 图片存储（规格 §2：应用专属目录 + **只存相对路径**）
void main() {
  group('DiaryMediaStore', () {
    late Directory tempRoot;
    late DiaryMediaStore store;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('diary_media_test_');
      store = DiaryMediaStore.withRoot(tempRoot);
    });

    tearDown(() async {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    Future<String> makeSource(
      String name, [
      List<int> bytes = const [1, 2, 3],
    ]) async {
      final f = File(p.join(tempRoot.path, name));
      await f.writeAsBytes(bytes);
      return f.path;
    }

    test('导入返回相对路径，且不包含临时目录的绝对路径', () async {
      final src = await makeSource('src.jpg');
      final rel = await store.importFile(src);
      expect(rel.startsWith('${DiaryMediaStore.folderName}/'), isTrue);
      expect(rel.contains(tempRoot.path), isFalse, reason: '绝对不能把绝对路径写进数据库');
      expect(rel.endsWith('.jpg'), isTrue);
    });

    test('文件被真正复制到 diary_media/ 下，源文件删掉不影响副本', () async {
      final src = await makeSource('src.png');
      final rel = await store.importFile(src);
      final copy = store.fileFor(rel);
      expect(copy.existsSync(), isTrue);

      await File(src).delete();
      expect(copy.existsSync(), isTrue);
      expect(copy.readAsBytesSync(), [1, 2, 3]);
    });

    test('同名源文件两次导入 → 两个不同文件（不覆盖）', () async {
      final src = await makeSource('same.jpg');
      final a = await store.importFile(src);
      final b = await store.importFile(src);
      expect(a, isNot(b));
      expect(store.exists(a) && store.exists(b), isTrue);
    });

    test('非白名单扩展名归一为 .jpg（挡住 .svg / 可执行后缀）', () async {
      final src = await makeSource('evil.svg');
      final rel = await store.importFile(src);
      expect(rel.endsWith('.jpg'), isTrue);
    });

    test('remove 删掉文件，且对不存在的路径不抛异常', () async {
      final src = await makeSource('gone.jpg');
      final rel = await store.importFile(src);
      expect(store.exists(rel), isTrue);
      await store.remove(rel);
      expect(store.exists(rel), isFalse);
      await store.remove(rel); // 再来一次不炸
    });

    test('相对路径在「换一个沙盒目录」后依然能解析（这就是不存绝对路径的意义）', () async {
      final src = await makeSource('move.jpg');
      final rel = await store.importFile(src);

      // 模拟 App 重装后文档目录变化：把整个 diary_media 搬到新 root
      final newRoot = await Directory.systemTemp.createTemp('diary_media_new_');
      try {
        final newFolder = Directory(
          p.join(newRoot.path, DiaryMediaStore.folderName),
        );
        await newFolder.create(recursive: true);
        await store.fileFor(rel).copy(p.join(newFolder.path, p.basename(rel)));

        final movedStore = DiaryMediaStore.withRoot(newRoot);
        expect(movedStore.exists(rel), isTrue);
      } finally {
        await newRoot.delete(recursive: true);
      }
    });
  });
}
