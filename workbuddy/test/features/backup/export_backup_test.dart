import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:efficiency_app/features/backup/application/export_backup.dart';
import 'package:efficiency_app/features/backup/data/backup_zip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 导出 ZIP：不依赖真机 / 不依赖真数据库。
///
/// 为什么把 `checkpoint` 做成注入项：生产环境跑的是
/// `PRAGMA wal_checkpoint(FULL)`，单测里只需要确认「读文件之前确实调了它」，
/// 用一个计数闭包比造一个真 SQLite 连接更能说明顺序。
void main() {
  late Directory root;
  late Directory docs;
  late Directory support;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup_test_');
    docs = Directory(p.join(root.path, 'documents'))
      ..createSync(recursive: true);
    support = Directory(p.join(root.path, 'support'))
      ..createSync(recursive: true);
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  BackupExporter buildExporter({
    Future<void> Function()? checkpoint,
    String appVersion = '1.0.0',
  }) {
    return BackupExporter(
      checkpoint: checkpoint ?? () async {},
      schemaVersion: 8,
      documentsDirectory: () async => docs,
      supportDirectory: () async => support,
      appVersion: appVersion,
    );
  }

  void writeDatabase(List<int> bytes) {
    File(
      p.join(docs.path, BackupEntries.database),
    ).writeAsBytesSync(bytes, flush: true);
  }

  group('BackupExporter · 导出', () {
    test('生成带时间戳的 zip，包含数据库 + 设置 + manifest', () async {
      writeDatabase(List.filled(2048, 7));
      File(
        p.join(support.path, BackupEntries.settings),
      ).writeAsStringSync('{"themeMode":"dark"}');

      final result = await buildExporter().export(
        now: DateTime(2026, 10, 28, 23, 45, 6),
      );

      expect(result.file.existsSync(), isTrue);
      expect(
        p.basename(result.file.path),
        'efficiency_app_backup_20261028_234506.zip',
      );
      expect(result.bytes, greaterThan(0));
      expect(
        result.entries,
        containsAll([
          BackupEntries.database,
          BackupEntries.settings,
          BackupEntries.manifest,
        ]),
      );

      final archive = ZipDecoder().decodeBytes(result.file.readAsBytesSync());
      final names = archive.files.map((f) => f.name).toList();
      expect(names, contains(BackupEntries.database));
      expect(names, contains(BackupEntries.settings));
      expect(names, contains(BackupEntries.manifest));

      // 数据库字节必须**原样**进包，不能被文本化/截断。
      final dbEntry = archive.files.firstWhere(
        (f) => f.name == BackupEntries.database,
      );
      expect(dbEntry.content as List<int>, List.filled(2048, 7));

      final manifest =
          jsonDecode(
                utf8.decode(
                  archive.files
                          .firstWhere((f) => f.name == BackupEntries.manifest)
                          .content
                      as List<int>,
                ),
              )
              as Map<String, dynamic>;
      expect(manifest['format'], 'efficiency_app_backup');
      expect(manifest['formatVersion'], kBackupFormatVersion);
      expect(manifest['schemaVersion'], 8);
      expect(manifest['appVersion'], '1.0.0');
      expect(manifest['exportedAt'], '2026-10-28T23:45:06.000');
    });

    test('先做 wal_checkpoint，再读数据库文件', () async {
      writeDatabase([1, 2, 3]);
      var checkpointCalled = false;

      final result = await buildExporter(
        checkpoint: () async {
          checkpointCalled = true;
          // 断言「checkpoint 时数据库已经存在」，且此刻读取到的就是主库内容
          expect(
            File(p.join(docs.path, BackupEntries.database)).existsSync(),
            isTrue,
          );
        },
      ).export(now: DateTime(2026, 10, 28, 12));

      expect(checkpointCalled, isTrue);
      expect(result.file.existsSync(), isTrue);
    });

    test('WAL 仍有残留时一并打包（避免丢最近事务）', () async {
      writeDatabase(List.filled(1024, 1));
      File(
        '${p.join(docs.path, BackupEntries.database)}-wal',
      ).writeAsBytesSync(List.filled(256, 2), flush: true);

      final result = await buildExporter().export();
      final archive = ZipDecoder().decodeBytes(result.file.readAsBytesSync());

      expect(
        archive.files.map((f) => f.name),
        contains(BackupEntries.databaseWal),
      );
    });

    test('没有设置文件也能导出（不把可选文件当必需）', () async {
      writeDatabase(List.filled(512, 3));

      final result = await buildExporter().export();

      expect(result.entries, isNot(contains(BackupEntries.settings)));
      expect(result.file.existsSync(), isTrue);
    });

    test('数据库不存在 → 明确失败，不产出半成品 zip', () async {
      await expectLater(
        buildExporter().export(),
        throwsA(isA<BackupException>()),
      );
      final backups = Directory(p.join(docs.path, 'backups'));
      expect(backups.existsSync() && backups.listSync().isNotEmpty, isFalse);
    });

    test('多次导出不会互相覆盖（文件名精确到秒）', () async {
      writeDatabase([9]);

      final a = await buildExporter().export(
        now: DateTime(2026, 10, 28, 8, 0, 1),
      );
      final b = await buildExporter().export(
        now: DateTime(2026, 10, 28, 8, 0, 2),
      );

      expect(a.file.path, isNot(b.file.path));
      expect(a.file.existsSync() && b.file.existsSync(), isTrue);
    });
  });

  group('formatBackupBytes', () {
    test('B / KB / MB 三档', () {
      expect(formatBackupBytes(512), '512 B');
      expect(formatBackupBytes(2048), '2.0 KB');
      expect(formatBackupBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBackupBytes(20 * 1024 * 1024), '20 MB');
    });
  });
}
