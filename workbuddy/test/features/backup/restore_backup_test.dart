import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/backup/application/restore_backup.dart';
import 'package:efficiency_app/features/backup/data/backup_zip.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// R2 · 从备份恢复。
///
/// 这一层的测试全部落在**真实文件**上（临时目录 + 真 SQLite），不 mock 文件系统：
/// 恢复的难点恰恰是「关连接 / 删 sidecar / rename / 回滚」这些真实 IO 顺序，
/// 用内存 mock 掉就什么都验不出来了。
void main() {
  late Directory root;
  late Directory docs;
  late File dbFile;

  const schemaVersion = AppDatabase.currentSchemaVersion;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('restore_test_');
    docs = Directory(p.join(root.path, 'documents'))
      ..createSync(recursive: true);
    dbFile = File(p.join(docs.path, BackupEntries.database));
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// 造一个**真的** SQLite 库（带 N 条模板）并返回它的字节。
  ///
  /// 为什么不用手搓假字节：`user_version` 与页结构都由 SQLite 自己写，
  /// 手搓的文件没有 `sqlite_master`，恢复后的自检会失败 —— 那样测的就不是恢复。
  ///
  /// 末尾那次 `SELECT 1` 不是多余的：drift 的 `NativeDatabase` 是**惰性**的，
  /// 一条 insert 都没做时连文件都不会创建，`readAsBytes` 会直接 PathNotFound。
  Future<List<int>> createDatabaseAt(File file, int templateCount) async {
    final db = AppDatabase(NativeDatabase(file));
    for (var i = 0; i < templateCount; i++) {
      await db
          .into(db.taskTemplates)
          .insert(
            TaskTemplatesCompanion.insert(
              type: TaskType.study.name,
              title: '备份任务$i',
              repeatMode: RepeatMode.daily.name,
              startDate: DateTime(2026, 11, 1),
            ),
          );
    }
    await db.customSelect('SELECT 1').getSingle();
    await db.close();
    return file.readAsBytes();
  }

  Future<int> countTemplates(File file) async {
    final db = AppDatabase(NativeDatabase(file));
    try {
      final rows = await db
          .customSelect('SELECT count(*) AS c FROM task_templates')
          .getSingle();
      return rows.data['c'] as int;
    } finally {
      await db.close();
    }
  }

  File writeZip(Map<String, List<int>> entries, {String name = 'b.zip'}) {
    final file = File(p.join(root.path, name));
    file.writeAsBytesSync(encodeBackupZip(entries), flush: true);
    return file;
  }

  RestoreBackup buildRestorer({
    required Future<void> Function() closeCurrent,
    Future<AppDatabase> Function(File file)? openDatabase,
    Future<void> Function(AppDatabase db)? install,
    Future<void> Function()? checkpoint,
  }) {
    return RestoreBackup(
      checkpoint: checkpoint ?? () async {},
      closeCurrent: closeCurrent,
      openDatabase:
          openDatabase ?? (file) async => AppDatabase(NativeDatabase(file)),
      install: install ?? (_) async {},
      databaseFile: () async => dbFile,
      schemaVersion: schemaVersion,
    );
  }

  group('inspectBackupBytes · 校验', () {
    test('改后缀的 txt（不是 ZIP）→ 明确拒绝', () {
      final fake = File(p.join(root.path, 'fake.zip'))
        ..writeAsBytesSync(utf8.encode('这不是一个 zip 文件'), flush: true);

      expect(
        () => inspectBackupBytes(
          fake.readAsBytesSync(),
          path: fake.path,
          currentSchemaVersion: schemaVersion,
        ),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            contains('不是有效的 ZIP'),
          ),
        ),
      );
    });

    test('ZIP 里没有数据库文件 → 拒绝，并列出包内文件', () {
      final zip = writeZip({
        'readme.txt': utf8.encode('hello'),
      });

      expect(
        () => inspectBackupBytes(
          zip.readAsBytesSync(),
          path: zip.path,
          currentSchemaVersion: schemaVersion,
        ),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            allOf(contains('没有 ${BackupEntries.database}'), contains('readme')),
          ),
        ),
      );
    });

    test('数据库头不是 SQLite format 3 → 拒绝', () {
      final zip = writeZip({
        BackupEntries.database: List<int>.filled(200, 65), // 全 'A'
      });

      expect(
        () => inspectBackupBytes(
          zip.readAsBytesSync(),
          path: zip.path,
          currentSchemaVersion: schemaVersion,
        ),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            contains('SQLite format 3'),
          ),
        ),
      );
    });

    test('文件不足 64 字节 → 拒绝（读不到 user_version）', () {
      final bytes = <int>[...utf8.encode('SQLite format 3'), 0, 1, 2, 3];
      final zip = writeZip({BackupEntries.database: bytes});

      expect(
        () => inspectBackupBytes(
          zip.readAsBytesSync(),
          path: zip.path,
          currentSchemaVersion: schemaVersion,
        ),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            contains('不完整'),
          ),
        ),
      );
    });

    test('user_version 高于当前 → 提示「来自更新版本」并拒绝', () {
      final bytes = List<int>.filled(128, 0);
      final header = utf8.encode('SQLite format 3');
      for (var i = 0; i < header.length; i++) {
        bytes[i] = header[i];
      }
      // offset 60..63 big-endian = 99
      bytes[60] = 0;
      bytes[61] = 0;
      bytes[62] = 0;
      bytes[63] = 99;

      final zip = writeZip({BackupEntries.database: bytes});

      expect(
        () => inspectBackupBytes(
          zip.readAsBytesSync(),
          path: zip.path,
          currentSchemaVersion: schemaVersion,
        ),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            contains('备份来自更新的版本'),
          ),
        ),
      );
    });

    test('真库导出 → 通过，并读出 schemaVersion 与 manifest', () async {
      final dbBytes = await createDatabaseAt(dbFile, 2);
      final zip = writeZip({
        BackupEntries.database: dbBytes,
        BackupEntries.manifest: utf8.encode(
          buildBackupManifest(
            exportedAt: DateTime(2026, 11, 18, 9, 30),
            schemaVersion: schemaVersion,
            entrySizes: {BackupEntries.database: dbBytes.length},
            appVersion: '1.3.0',
          ),
        ),
      });

      final preview = inspectBackupBytes(
        zip.readAsBytesSync(),
        path: zip.path,
        currentSchemaVersion: schemaVersion,
      );

      expect(preview.databaseUserVersion, schemaVersion);
      expect(preview.manifest?.appVersion, '1.3.0');
      expect(preview.backedUpAt, DateTime(2026, 11, 18, 9, 30));
      expect(preview.sizeLabel, isNotEmpty);
    });
  });

  group('RestoreBackup · 覆盖与回滚', () {
    test('恢复成功：数据回到备份时状态，并留下 .pre_restore.bak', () async {
      // 当前库：1 条模板
      await createDatabaseAt(dbFile, 1);
      var current = AppDatabase(NativeDatabase(dbFile));
      expect(await countTemplates(dbFile), 1);

      // 备份库：3 条模板（用另一个文件造，再造包）
      final other = File(p.join(root.path, 'other.sqlite'));
      final backupBytes = await createDatabaseAt(other, 3);

      final zip = writeZip({BackupEntries.database: backupBytes});
      final preview = inspectBackupBytes(
        zip.readAsBytesSync(),
        path: zip.path,
        currentSchemaVersion: schemaVersion,
      );

      var installed = 0;
      final restorer = buildRestorer(
        closeCurrent: () async {
          await current.close();
        },
        install: (db) async {
          installed++;
          current = db;
        },
      );

      final result = await restorer.restore(preview);

      expect(result.userVersion, schemaVersion);
      expect(result.rows, greaterThan(0));
      expect(installed, 1, reason: '新库必须被装进应用，否则界面还是旧数据');

      // 恢复后的库就是备份里那份
      expect(await countTemplates(dbFile), 3);

      // 安全副本保留的是**恢复前**那份（1 条）
      final safety = File('${dbFile.path}${RestoreBackup.safetySuffix}');
      expect(safety.existsSync(), isTrue);
      expect(await countTemplates(safety), 1);

      // 临时文件与 sidecar 不留
      expect(File('${dbFile.path}.restoring').existsSync(), isFalse);
      expect(File('${dbFile.path}-wal').existsSync(), isFalse);
      expect(File('${dbFile.path}-shm').existsSync(), isFalse);

      await current.close();
    });

    test('替换后打不开 → 自动回滚，原数据一条不少', () async {
      await createDatabaseAt(dbFile, 2);
      var current = AppDatabase(NativeDatabase(dbFile));

      final badBytes = <int>[
        ...utf8.encode('SQLite format 3'),
        0,
        // 头部像 SQLite，但后面全是垃圾 → 打开/自检必炸
        ...List<int>.filled(4000, 0),
      ];
      final zip = writeZip({BackupEntries.database: badBytes});
      final preview = BackupPreview(
        file: zip,
        bytes: zip.lengthSync(),
        entries: [BackupEntries.database],
        databaseUserVersion: schemaVersion,
        manifest: null,
      );

      var openAttempts = 0;
      var installed = 0;
      final restorer = buildRestorer(
        closeCurrent: () async {
          await current.close();
        },
        openDatabase: (file) async {
          openAttempts++;
          // 第一次打开（替换后的坏文件）成功返回一个连接，但自检会失败；
          // 第二次（回滚后的好文件）正常。
          return AppDatabase(NativeDatabase(file));
        },
        install: (db) async {
          installed++;
          current = db;
        },
      );

      await expectLater(
        restorer.restore(preview),
        throwsA(isA<RestoreException>()),
      );

      expect(openAttempts, greaterThanOrEqualTo(2), reason: '失败后必须重开降级的旧库');
      expect(installed, 1, reason: '回滚后的库必须重新装回应用');
      expect(await countTemplates(dbFile), 2, reason: '原数据必须完整回来');

      await current.close();
    });

    test('备份文件在确认后被删掉 → 明确失败，不动现有数据', () async {
      await createDatabaseAt(dbFile, 1);
      var current = AppDatabase(NativeDatabase(dbFile));

      final other = File(p.join(root.path, 'other.sqlite'));
      // 备份里是**空库**（0 条模板）：恢复后当前库应变成 0 条，与备份一致。
      final backupBytes = await createDatabaseAt(other, 0);
      final zip = writeZip({BackupEntries.database: backupBytes});
      final preview = inspectBackupBytes(
        zip.readAsBytesSync(),
        path: zip.path,
        currentSchemaVersion: schemaVersion,
      );
      zip.deleteSync();

      final restorer = buildRestorer(
        closeCurrent: () async {
          await current.close();
        },
        install: (db) async {
          current = db;
        },
      );

      await expectLater(
        restorer.restore(preview),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            contains('已被移动或删除'),
          ),
        ),
      );

      // 连 checkpoint 都没走完就退出了：现有库仍然可读、行数不变
      expect(await countTemplates(dbFile), 1);
      await current.close();
    });

    test('checkpoint 失败 → 直接中止，不写盘', () async {
      await createDatabaseAt(dbFile, 1);
      var closed = false;
      final current = AppDatabase(NativeDatabase(dbFile));

      final other = File(p.join(root.path, 'other.sqlite'));
      // 备份里是**空库**（0 条模板）：恢复后当前库应变成 0 条，与备份一致。
      final backupBytes = await createDatabaseAt(other, 0);
      final zip = writeZip({BackupEntries.database: backupBytes});
      final preview = inspectBackupBytes(
        zip.readAsBytesSync(),
        path: zip.path,
        currentSchemaVersion: schemaVersion,
      );

      final restorer = buildRestorer(
        checkpoint: () async => throw StateError('disk full'),
        closeCurrent: () async {
          closed = true;
          await current.close();
        },
      );

      await expectLater(
        restorer.restore(preview),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            contains('合并 WAL 失败'),
          ),
        ),
      );

      expect(closed, isFalse, reason: 'checkpoint 失败时不该走到关闭连接这一步');
      expect(await countTemplates(dbFile), 1);
      await current.close();
    });

    test('恢复后补齐今日实例由 install 负责（这里只验证回调被调用一次）', () async {
      await createDatabaseAt(dbFile, 0);
      var current = AppDatabase(NativeDatabase(dbFile));

      final other = File(p.join(root.path, 'other.sqlite'));
      // 备份里是**空库**（0 条模板）：恢复后当前库应变成 0 条，与备份一致。
      final backupBytes = await createDatabaseAt(other, 0);
      final zip = writeZip({BackupEntries.database: backupBytes});
      final preview = inspectBackupBytes(
        zip.readAsBytesSync(),
        path: zip.path,
        currentSchemaVersion: schemaVersion,
      );

      var calls = 0;
      final restorer = buildRestorer(
        closeCurrent: () async {
          await current.close();
        },
        install: (db) async {
          calls++;
          current = db;
        },
      );

      await restorer.restore(preview);
      expect(calls, 1);
      await current.close();
    });
  });
}
