import 'dart:io';

import 'package:efficiency_app/core/settings/app_settings.dart';
import 'package:efficiency_app/features/backup/application/auto_backup_service.dart';
import 'package:efficiency_app/features/backup/application/export_backup.dart';
import 'package:efficiency_app/features/backup/data/backup_zip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// R3 任务 2：自动备份（7 天间隔 · 保留 4 份）。
///
/// 分两层测：
/// 1. **纯函数** —— `shouldBackup` 判定与轮转裁剪。这两处最容易写错
///    （边界天数、排序不稳定导致「该留的被删」），而且完全不需要 IO；
/// 2. **真流程** —— 临时目录里放一个假数据库，让服务真的导出、真的轮转，
///    再数磁盘上剩下几个文件。纯函数测不到「删错文件」这类事故。
void main() {
  group('shouldAutoBackup · 判定', () {
    final now = DateTime(2026, 11, 19, 22, 40);

    test('从未备份过 → 立即备份', () {
      expect(shouldAutoBackup(null, now), isTrue);
    });

    test('6 天 23 小时 → 还不到点（按整天算）', () {
      final last = now.subtract(const Duration(days: 6, hours: 23));
      expect(shouldAutoBackup(last, now), isFalse);
    });

    test('正好 7 天 → 到点', () {
      expect(
        shouldAutoBackup(now.subtract(const Duration(days: 7)), now),
        isTrue,
      );
    });

    test('8 天前 → 到点（验收里的那条）', () {
      expect(
        shouldAutoBackup(now.subtract(const Duration(days: 8)), now),
        isTrue,
      );
    });

    test('时间戳在未来（用户改过系统时间）→ 不备份，而不是疯狂备份', () {
      final future = now.add(const Duration(days: 30));
      expect(shouldAutoBackup(future, now), isFalse);
    });

    test('间隔可配置', () {
      final last = now.subtract(const Duration(days: 3));
      expect(shouldAutoBackup(last, now), isFalse);
      expect(shouldAutoBackup(last, now, intervalDays: 3), isTrue);
    });
  });

  group('pruneAutoBackups · 裁剪', () {
    AutoBackupFile f(String name, int day) =>
        AutoBackupFile(name: name, modified: DateTime(2026, 11, day));

    test('4 份以内全留', () {
      final files = [f('auto_backup_a.zip', 1), f('auto_backup_b.zip', 2)];
      final kept = pruneAutoBackups(files, 4);
      expect(kept.map((e) => e.name), [
        'auto_backup_b.zip',
        'auto_backup_a.zip',
      ]);
    });

    test('超过 4 份 → 只留最新的 4 份（新的在前）', () {
      final files = [
        for (var d = 1; d <= 6; d++) f('auto_backup_2026110$d.zip', d),
      ];
      final kept = pruneAutoBackups(files, 4);
      expect(kept.length, 4);
      expect(kept.map((e) => e.name), [
        'auto_backup_20261106.zip',
        'auto_backup_20261105.zip',
        'auto_backup_20261104.zip',
        'auto_backup_20261103.zip',
      ]);
    });

    test('修改时间完全相同 → 按文件名定序，结果稳定（不会随机删）', () {
      final same = DateTime(2026, 11, 19, 12);
      final files = [
        AutoBackupFile(name: 'auto_backup_20261119_120000.zip', modified: same),
        AutoBackupFile(name: 'auto_backup_20261119_120002.zip', modified: same),
        AutoBackupFile(name: 'auto_backup_20261119_120001.zip', modified: same),
      ];
      final first = pruneAutoBackups(files, 2).map((e) => e.name).toList();
      final second = pruneAutoBackups(files, 2).map((e) => e.name).toList();
      expect(first, second);
      expect(first, [
        'auto_backup_20261119_120002.zip',
        'auto_backup_20261119_120001.zip',
      ]);
    });

    test('keep <= 0 → 一个都不留（不崩）', () {
      expect(pruneAutoBackups([f('auto_backup_a.zip', 1)], 0), isEmpty);
    });
  });

  group('autoBackupStatusLabel · 设置页文案', () {
    final now = DateTime(2026, 11, 19, 10);

    test('从未备份 / 今天 / 昨天 / N 天前', () {
      expect(autoBackupStatusLabel(null, now), '尚未备份过');
      expect(autoBackupStatusLabel(DateTime(2026, 11, 19, 8), now), '今天刚备份过');
      expect(autoBackupStatusLabel(DateTime(2026, 11, 18, 23), now), '上次备份：昨天');
      expect(
        autoBackupStatusLabel(DateTime(2026, 11, 15, 10), now),
        '上次备份：4 天前',
      );
    });
  });

  group('AutoBackupService · 真流程（临时目录）', () {
    late Directory root;
    late Directory docs;
    late Directory support;
    late AppSettings settings;
    late List<int?> writtenTimestamps;
    var now = DateTime(2026, 11, 19, 14, 30);

    setUp(() async {
      root = await Directory.systemTemp.createTemp('auto_backup_');
      docs = Directory(p.join(root.path, 'documents'))..createSync();
      support = Directory(p.join(root.path, 'support'))..createSync();
      settings = const AppSettings();
      writtenTimestamps = [];
      now = DateTime(2026, 11, 19, 14, 30);
      // 导出链路只要求「主库文件存在」，内容不重要
      File(
        p.join(docs.path, BackupEntries.database),
      ).writeAsBytesSync(List.filled(2048, 7), flush: true);
    });

    tearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });

    AutoBackupService buildService({
      Future<void> Function()? checkpoint,
      int keepCount = AutoBackupService.defaultKeepCount,
    }) {
      return AutoBackupService(
        exporter: BackupExporter(
          checkpoint: checkpoint ?? () async {},
          schemaVersion: 8,
          documentsDirectory: () async => docs,
          supportDirectory: () async => support,
          appVersion: '1.5.0',
        ),
        readSettings: () async => settings,
        writeLastAutoBackupAt: ({int? lastAutoBackupAt}) async {
          writtenTimestamps.add(lastAutoBackupAt);
          settings = settings.copyWith(lastAutoBackupAt: lastAutoBackupAt);
        },
        clock: () => now,
        keepCount: keepCount,
      );
    }

    Directory backupsDir() => Directory(p.join(docs.path, kBackupSubdir));

    List<String> autoBackupNames() {
      final dir = backupsDir();
      if (!dir.existsSync()) return const [];
      return dir
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((n) => n.startsWith(kAutoBackupPrefix) && n.endsWith('.zip'))
          .toList()
        ..sort();
    }

    test('从未备份过 → 真写出一份 auto_backup_ 包，并记录时间戳', () async {
      final result = await buildService().maybeBackup();

      expect(result.created, isTrue);
      expect(result.error, isNull);
      expect(result.zipName, 'auto_backup_20261119_143000.zip');
      expect(result.keptCount, 1);
      expect(autoBackupNames(), ['auto_backup_20261119_143000.zip']);
      expect(writtenTimestamps, [now.millisecondsSinceEpoch]);

      // 包里必须是真的数据库字节（复用导出链路，不是写了个空壳）
      expect(
        File(p.join(backupsDir().path, result.zipName!)).lengthSync(),
        greaterThan(0),
      );
    });

    test('开关关闭 → 跳过，不写文件、不改时间戳', () async {
      settings = settings.copyWith(autoBackupEnabled: false);

      final result = await buildService().maybeBackup();

      expect(result.skipped, isTrue);
      expect(result.created, isFalse);
      expect(autoBackupNames(), isEmpty);
      expect(writtenTimestamps, isEmpty);
    });

    test('未到 7 天 → 跳过；8 天前 → 备份（验收第 1 条）', () async {
      settings = settings.copyWith(
        lastAutoBackupAt: now
            .subtract(const Duration(days: 6))
            .millisecondsSinceEpoch,
      );
      expect((await buildService().maybeBackup()).skipped, isTrue);
      expect(autoBackupNames(), isEmpty);

      settings = settings.copyWith(
        lastAutoBackupAt: now
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch,
      );
      final result = await buildService().maybeBackup();
      expect(result.created, isTrue);
      expect(autoBackupNames(), hasLength(1));
    });

    test('连续触发 5 次 → 只留 4 份，最旧的一份被删（验收第 2 条）', () async {
      final service = buildService();

      for (var i = 0; i < 5; i++) {
        now = DateTime(2026, 11, 19, 14, 30, i);
        final result = await service.maybeBackup(force: true);
        expect(result.created, isTrue, reason: '第 $i 次应真的写出文件');
        expect(result.keptCount, i + 1 > 4 ? 4 : i + 1);
      }

      final names = autoBackupNames();
      expect(names, hasLength(4));
      expect(names, [
        'auto_backup_20261119_143001.zip',
        'auto_backup_20261119_143002.zip',
        'auto_backup_20261119_143003.zip',
        'auto_backup_20261119_143004.zip',
      ]);
      // 最旧的（143000）被删掉了
      expect(names, isNot(contains('auto_backup_20261119_143000.zip')));
    });

    test('手动导出的包永不被轮转删掉（只认 auto_backup_ 前缀）', () async {
      // 先放两个「手动导出」的包 + 一个像备份但不是 .zip 的残留
      final dir = backupsDir()..createSync(recursive: true);
      File(
        p.join(dir.path, 'efficiency_app_backup_20261101_090000.zip'),
      ).writeAsBytesSync([1, 2, 3]);
      File(
        p.join(dir.path, 'efficiency_app_backup_20261102_090000.zip'),
      ).writeAsBytesSync([4, 5, 6]);
      File(
        p.join(dir.path, 'auto_backup_20260101_000000.zip.bak'),
      ).writeAsBytesSync([7]);

      final service = buildService();
      for (var i = 0; i < 5; i++) {
        now = DateTime(2026, 11, 19, 14, 30, i);
        await service.maybeBackup(force: true);
      }

      final all = dir
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toList();
      expect(all, contains('efficiency_app_backup_20261101_090000.zip'));
      expect(all, contains('efficiency_app_backup_20261102_090000.zip'));
      // `.zip.bak` 不是备份，不该被算进 4 份、也不该被删
      expect(all, contains('auto_backup_20260101_000000.zip.bak'));
      expect(autoBackupNames(), hasLength(4));
    });

    test('导出失败（库文件缺失）→ 返回错误，且**不写**时间戳', () async {
      File(p.join(docs.path, BackupEntries.database)).deleteSync();

      final result = await buildService().maybeBackup();

      expect(result.created, isFalse);
      expect(result.error, isNotNull);
      expect(writtenTimestamps, isEmpty, reason: '失败不能推进计时，否则白等 7 天');
      expect(autoBackupNames(), isEmpty);
    });

    test('并发调用只跑一次（同一次启动里的重复触发）', () async {
      final service = buildService();
      final futures = [
        service.maybeBackup(force: true),
        service.maybeBackup(force: true),
        service.maybeBackup(force: true),
      ];
      final results = await Future.wait(futures);

      expect(results.every((r) => r.created), isTrue);
      expect(autoBackupNames(), hasLength(1), reason: '三次调用应共用同一次导出');
    });

    test('keepCount 可配置（保留 2 份）', () async {
      final service = buildService(keepCount: 2);
      for (var i = 0; i < 4; i++) {
        now = DateTime(2026, 11, 19, 14, 30, i);
        await service.maybeBackup(force: true);
      }
      expect(autoBackupNames(), [
        'auto_backup_20261119_143002.zip',
        'auto_backup_20261119_143003.zip',
      ]);
    });
  });
}
