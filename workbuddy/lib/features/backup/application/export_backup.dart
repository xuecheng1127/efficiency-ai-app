import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../data/backup_zip.dart';

/// 导出结果：路径、大小、包内文件 —— SnackBar 与测试都用这份**事实**，
/// 不在 UI 里再拼一遍字符串。
class BackupResult {
  const BackupResult({
    required this.file,
    required this.bytes,
    required this.entries,
  });

  final File file;
  final int bytes;
  final List<String> entries;

  String get fileName => p.basename(file.path);
}

/// 导出失败（可读原因，直接能显示给用户）。
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 字节数格式化（B / KB / MB）：给 SnackBar 用的「人话大小」。
String formatBackupBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
}

/// ============================================================================
/// 导出全部数据为 ZIP
/// ============================================================================
///
/// 流程（与需求逐条对应）：
/// 1. `PRAGMA wal_checkpoint(FULL)` —— WAL 里的最新事务合并回主库，
///    否则「刚完成的任务」可能只存在于 `-wal`，备份出来少一截；
/// 2. 打包主库（若 `-wal` 仍有残留就一并带上，保证可恢复）+ `app_settings.json`；
/// 3. 写 manifest（格式版本 / schema 版本 / 导出时间 / 各文件大小）；
/// 4. 写入应用文档目录 `backups/`，文件名带时间戳；
/// 5. 返回路径与大小，由 UI 显示并可选调系统分享。
///
/// 压缩在 `Isolate.run` 里做（README 的约束）：数据库几十 MB 时同步压缩会卡住
/// 首帧，用户会以为「点了没反应」。
class BackupExporter {
  BackupExporter({
    required Future<void> Function() checkpoint,
    required int schemaVersion,
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? supportDirectory,
    this.appVersion = '1.0.0',
  }) : _checkpoint = checkpoint,
       _schemaVersion = schemaVersion,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  /// 绑定真实数据库的构造（生产路径）。
  factory BackupExporter.forDatabase(
    AppDatabase db, {
    String appVersion = '1.0.0',
  }) {
    return BackupExporter(
      // customSelect 走同一条连接，PRAGMA 才会作用在正在使用的库上。
      checkpoint: () => db.customSelect('PRAGMA wal_checkpoint(FULL)').get(),
      schemaVersion: db.schemaVersion,
      appVersion: appVersion,
    );
  }

  final Future<void> Function() _checkpoint;
  final int _schemaVersion;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _supportDirectory;
  final String appVersion;

  /// 执行导出。[now] 仅供测试注入固定时间（文件名的确定性）。
  Future<BackupResult> export({DateTime? now}) async {
    final stamp = now ?? DateTime.now();

    await _checkpoint();

    final docs = await _documentsDirectory();
    final dbFile = File(p.join(docs.path, 'efficiency_app.sqlite'));
    if (!dbFile.existsSync()) {
      throw BackupException('数据库文件不存在：${dbFile.path}');
    }

    final payload = <String, List<int>>{
      BackupEntries.database: await dbFile.readAsBytes(),
    };

    // checkpoint 之后 -wal 通常已被截断为 0；若仍有内容说明有并发写入，
    // 一起打包才不会丢最近的事务。
    final walFile = File('${dbFile.path}-wal');
    if (walFile.existsSync() && walFile.lengthSync() > 0) {
      payload[BackupEntries.databaseWal] = await walFile.readAsBytes();
    }

    // 设置（主题、火花缓存等）不是数据库里的行，单独带上。
    final settingsFile = File(
      p.join((await _supportDirectory()).path, 'app_settings.json'),
    );
    if (settingsFile.existsSync()) {
      payload[BackupEntries.settings] = await settingsFile.readAsBytes();
    }

    final sizes = {for (final e in payload.entries) e.key: e.value.length};
    payload[BackupEntries.manifest] = utf8.encode(
      buildBackupManifest(
        exportedAt: stamp,
        schemaVersion: _schemaVersion,
        entrySizes: sizes,
        appVersion: appVersion,
      ),
    );

    // 大文件压缩放后台 isolate：不阻塞 UI。
    final zipBytes = await Isolate.run(() => encodeBackupZip(payload));

    final outDir = Directory(p.join(docs.path, 'backups'));
    if (!outDir.existsSync()) {
      await outDir.create(recursive: true);
    }
    final file = File(
      p.join(
        outDir.path,
        'efficiency_app_backup_${DateFormat('yyyyMMdd_HHmmss').format(stamp)}.zip',
      ),
    );
    await file.writeAsBytes(zipBytes, flush: true);

    return BackupResult(
      file: file,
      bytes: zipBytes.length,
      entries: payload.keys.toList(),
    );
  }
}
