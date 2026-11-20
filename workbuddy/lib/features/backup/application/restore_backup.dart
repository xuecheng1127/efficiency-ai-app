import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../data/backup_zip.dart';
import 'export_backup.dart' show formatBackupBytes;

/// 恢复相关日志（与导出同风格，`adb logcat -d | findstr restore` 可直接过滤）。
///
/// 为什么每一步都打：恢复是**破坏性写盘**，出问题时用户只记得「点了恢复，
/// 然后数据少了」。日志里留下「备份前库多大 / user_version 多少 / 回滚到哪个
/// 文件」，才可能事后查清到底停在哪一步。
const String restoreLogTag = '[backup][restore]';

void restoreLog(String message) {
  debugPrint('$restoreLogTag $message');
}

/// 恢复失败（[message] 是可以直接展示给用户的人话）。
class RestoreException implements Exception {
  const RestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 选中并校验过的备份包（**还没动任何数据**）。
///
/// 这个对象存在的意义就是把「看清里面是什么」和「动手覆盖」分成两步：
/// 二次确认弹窗要显示的文件名 / 大小 / 备份时间 / 备份版本，全部来自这里。
class BackupPreview {
  const BackupPreview({
    required this.file,
    required this.bytes,
    required this.entries,
    required this.databaseUserVersion,
    required this.manifest,
  });

  final File file;
  final int bytes;
  final List<String> entries;

  /// 备份内数据库文件头里的 `user_version`（= 导出时的 schemaVersion）。
  final int databaseUserVersion;

  final BackupManifestInfo? manifest;

  String get fileName => p.basename(file.path);

  String get sizeLabel => formatBackupBytes(bytes);

  /// 备份时间：优先 manifest（导出时刻），退化为文件修改时间。
  DateTime get backedUpAt =>
      manifest?.exportedAt ??
      DateTime.fromMillisecondsSinceEpoch(
        file.lastModifiedSync().millisecondsSinceEpoch,
      );

  String get backedUpAtLabel =>
      DateFormat('yyyy-MM-dd HH:mm').format(backedUpAt);

  String get appVersionLabel => manifest?.appVersion ?? '未知';
}

/// ============================================================================
/// 校验：把「这不是有效备份」的理由说清楚
/// ============================================================================
///
/// 全纯函数（不碰文件系统、不打开数据库），因此单测可以直接喂字节：
/// - 改后缀的 txt → 不是 ZIP；
/// - 空壳 zip → 少数据库；
/// - 随便塞的文本当 .sqlite → 头不对；
/// - 新版本导出的库 → user_version 超了，必须拒绝。
///
/// **绝不能用 drift 打开那个文件来读版本**：一打开就可能跑迁移，
/// 「来自新版本的库」会被当旧库升级，等于把备份就地毁了。
BackupPreview inspectBackupBytes(
  List<int> raw, {
  required String path,
  required int currentSchemaVersion,
}) {
  final fileName = p.basename(path);

  final BackupContents contents;
  try {
    contents = decodeBackupZip(raw);
  } on FormatException catch (e) {
    throw RestoreException(
      '「$fileName」不是有效的 ZIP 文件（${e.message}）。\n'
      '请确认选择的是「导出全部数据」生成的 .zip 备份包。',
    );
  }

  final dbBytes = contents[BackupEntries.database];
  if (dbBytes == null) {
    throw RestoreException(
      '「$fileName」里没有 ${BackupEntries.database}。\n'
      '这不是本应用导出的备份包（包内文件：${contents.entries.keys.join('、')}）。',
    );
  }

  if (!hasSqliteHeader(dbBytes)) {
    throw RestoreException(
      '「$fileName」里的数据库文件头不是「SQLite format 3」，'
      '文件已损坏或不是数据库（大小 ${formatBackupBytes(dbBytes.length)}）。',
    );
  }

  final userVersion = readSqliteUserVersion(dbBytes);
  if (userVersion == null) {
    throw RestoreException(
      '「$fileName」里的数据库文件不完整（只有 '
      '${dbBytes.length} 字节，至少要 $kSqliteHeaderMinBytes 字节），'
      '无法读取版本号 —— 备份包可能没下载完就被中断了。',
    );
  }

  if (userVersion > currentSchemaVersion) {
    throw RestoreException(
      '备份来自更新的版本（备份数据库 v$userVersion，当前只支持到 '
      'v$currentSchemaVersion）。\n'
      '请先把应用升级到与备份相同的版本，再恢复这份数据。',
    );
  }

  // manifest 与文件头不一致时以**文件头**为准（manifest 只是旁证），
  // 但要留下日志，便于判断是不是有人手改过包。
  final manifest = contents.manifest;
  if (manifest != null && manifest.schemaVersion != userVersion) {
    restoreLog(
      'manifest schemaVersion=${manifest.schemaVersion} '
      '与数据库头 user_version=$userVersion 不一致，以文件头为准',
    );
  }

  return BackupPreview(
    file: File(path),
    bytes: raw.length,
    entries: contents.entries.keys.toList(),
    databaseUserVersion: userVersion,
    manifest: manifest,
  );
}

/// 选包 + 校验（生产路径）。
///
/// 解压放 `Isolate.run`：几十 MB 的包在主 isolate 上解会卡住首帧，
/// 用户看到的是「点了恢复，界面愣住」。
class BackupInspector {
  BackupInspector({required this.schemaVersion});

  final int schemaVersion;

  Future<BackupPreview> inspect(File zip) async {
    if (!await zip.exists()) {
      throw RestoreException('备份文件不存在：${zip.path}');
    }
    final raw = await zip.readAsBytes();
    final path = zip.path;
    final schema = schemaVersion;
    restoreLog('inspect start: $path (${formatBackupBytes(raw.length)})');
    final preview = await Isolate.run(
      () => inspectBackupBytes(raw, path: path, currentSchemaVersion: schema),
    );
    restoreLog(
      'inspect ok: user_version=${preview.databaseUserVersion}, '
      'entries=${preview.entries.join(",")}',
    );
    return preview;
  }
}

/// 恢复完成后的**事实**（给 UI 直接展示，不在页面里再拼）。
class RestoreResult {
  const RestoreResult({
    required this.databaseFile,
    required this.safetyCopy,
    required this.userVersion,
    required this.rows,
  });

  /// 被恢复的库文件（应用文档目录下那个）。
  final File databaseFile;

  /// 覆盖前的安全副本（`.pre_restore.bak`），恢复成功也**不删**。
  final File? safetyCopy;

  /// 恢复后库文件头里的 user_version。
  final int userVersion;

  /// 恢复后 `sqlite_master` 里的对象数（粗略但真实的「库是活的」证据）。
  final int rows;
}

/// 打开数据库（生产 = [AppDatabase.open]，测试 = 内存库）。
typedef DatabaseOpener = Future<AppDatabase> Function(File file);

/// 把新库装进全应用（生产 = 换掉 Riverpod 里的实例并 backfill）。
typedef DatabaseInstaller = Future<void> Function(AppDatabase db);

/// ============================================================================
/// 从 ZIP 恢复
/// ============================================================================
///
/// 顺序（每一步失败都能停在一个**已知可用**的状态）：
/// 1. `PRAGMA wal_checkpoint(FULL)`：把 WAL 里还没落盘的事务并回主库，
///    否则「刚完成的任务」只存在于 `-wal`，安全副本会少一截；
/// 2. 把当前库整份复制成 `<db>.pre_restore.bak`（不删，永远留着）；
/// 3. close 当前连接 → 删 `-wal` / `-shm`（旧 WAL 属于旧库，留着会被
///    SQLite 当成新库的日志回放，直接损坏数据）；
/// 4. 写临时文件再 rename 覆盖（rename 失败走覆盖写兜底）；
/// 5. 重新打开 + `SELECT 1` + `sqlite_master` 自检；
/// 6. 自检失败 → **用安全副本回滚** → 重新打开并装回应用；
/// 7. 自检通过 → 装进应用（触发全量重建 + 今日实例 backfill）。
class RestoreBackup {
  RestoreBackup({
    required this.checkpoint,
    required this.closeCurrent,
    required this.openDatabase,
    required this.install,
    required this.databaseFile,
    required this.schemaVersion,
  });

  /// `PRAGMA wal_checkpoint(FULL)`（走当前连接，PRAGMA 才会作用在真库上）。
  final Future<void> Function() checkpoint;

  /// 关闭当前连接（必须是**同一个**连接，否则 rename 后旧连接还握着 inode）。
  final Future<void> Function() closeCurrent;

  final DatabaseOpener openDatabase;
  final DatabaseInstaller install;

  /// 当前数据库文件（生产 = [AppDatabase.defaultFile]）。
  final Future<File> Function() databaseFile;

  final int schemaVersion;

  static const String safetySuffix = '.pre_restore.bak';

  Future<RestoreResult> restore(BackupPreview preview) async {
    // 重新读一遍包：从「选中」到「确认」之间用户可能删了文件，
    // 也可能有别的程序改过它 —— 恢复写盘前必须拿到此刻的真实字节。
    final dbBytes = await _readDatabaseBytes(preview);

    final target = await databaseFile();
    final safetyCopy = File('${target.path}$safetySuffix');
    final hadCurrent = await target.exists();
    final currentSize = hadCurrent ? await target.length() : 0;

    restoreLog(
      'restore start: ${preview.fileName} '
      '(backup uv=${preview.databaseUserVersion}, ${formatBackupBytes(dbBytes.length)}) '
      '-> ${target.path} (current ${formatBackupBytes(currentSize)}, '
      'exists=$hadCurrent)',
    );

    // ---- 1. WAL 并回主库 -------------------------------------------------
    try {
      await checkpoint();
      restoreLog('checkpoint(FULL) ok');
    } catch (e) {
      throw RestoreException('合并 WAL 失败，未做任何改动：$e');
    }

    // ---- 2. 安全副本 -----------------------------------------------------
    if (hadCurrent) {
      try {
        await target.copy(safetyCopy.path);
        restoreLog(
          'safety copy ok: ${safetyCopy.path} '
          '(${formatBackupBytes(await safetyCopy.length())})',
        );
      } catch (e) {
        throw RestoreException('无法备份当前数据库（磁盘空间不足或目录不可写）：$e');
      }
    }

    // ---- 3. 关连接 + 清 sidecar -----------------------------------------
    try {
      await closeCurrent();
    } catch (e) {
      // 关不掉也继续：Android 的 POSIX 语义下，删/改名对打开的文件依然有效。
      restoreLog('close current db failed (continue): $e');
    }
    await _deleteSidecars(target);

    // ---- 4~7. 替换 / 自检 / 回滚 ----------------------------------------
    AppDatabase? next;
    try {
      await _replaceDatabase(target, dbBytes);
      restoreLog('database replaced (${formatBackupBytes(dbBytes.length)})');

      next = await openDatabase(target);
      final objects = await _selfCheck(next);
      restoreLog('self check ok: sqlite_master objects=$objects');

      await install(next);
      restoreLog('installed into app (providers rebuilt)');

      return RestoreResult(
        databaseFile: target,
        safetyCopy: hadCurrent ? safetyCopy : null,
        userVersion: preview.databaseUserVersion,
        rows: objects,
      );
    } catch (e) {
      restoreLog('restore FAILED: $e');
      if (next != null) {
        try {
          await next.close();
        } catch (_) {
          // 已经坏了/已关闭，忽略。
        }
      }
      await _rollback(target, safetyCopy, hadCurrent: hadCurrent, error: e);
      // _rollback 内部会把旧库重新装回应用，所以这里只需要把原因抛给 UI。
      throw RestoreException(
        '恢复失败：$e\n\n'
        '${hadCurrent ? '已回滚到恢复前的数据（${safetyCopy.path}）。' : '当前原本没有数据库，已清掉这次失败留下的残文件。'}',
      );
    }
  }

  /// 从选中/确认用的预览里再取一次数据库字节，并复核头与版本。
  Future<List<int>> _readDatabaseBytes(BackupPreview preview) async {
    if (!await preview.file.exists()) {
      throw RestoreException('备份文件已被移动或删除：${preview.file.path}');
    }
    final BackupContents contents;
    try {
      contents = decodeBackupZip(await preview.file.readAsBytes());
    } on FormatException catch (e) {
      throw RestoreException('备份文件已损坏：${e.message}');
    }
    final bytes = contents[BackupEntries.database];
    if (bytes == null) {
      throw const RestoreException('备份包里没有数据库文件，恢复中止');
    }
    if (!hasSqliteHeader(bytes)) {
      throw const RestoreException('备份里的数据库文件头不正确，恢复中止');
    }
    final uv = readSqliteUserVersion(bytes);
    if (uv == null) {
      throw const RestoreException('备份里的数据库文件不完整，恢复中止');
    }
    if (uv > schemaVersion) {
      throw RestoreException('备份来自更新的版本（v$uv > v$schemaVersion），恢复中止');
    }
    return bytes;
  }

  /// 自检：能查出 `sqlite_master` 才算「打开了一个真库」。
  ///
  /// 单独跑一次 `SELECT 1` 是不够的（任何空壳连接都能过），
  /// `sqlite_master` 会真的去读 file header + 页表，损坏文件在这里必炸。
  Future<int> _selfCheck(AppDatabase db) async {
    await db.customSelect('SELECT 1').getSingle();
    final row = await db
        .customSelect('SELECT count(*) AS c FROM sqlite_master')
        .getSingle();
    return row.data['c'] as int? ?? 0;
  }

  /// 用临时文件 + rename 覆盖（同目录，保证 rename 是原子替换）。
  ///
  /// rename 在 Windows 上对已存在的目标是会失败的（Android/POSIX 不会），
  /// 所以保留「覆盖写 + 删临时文件」的兜底路径 —— 单测在 Windows 上跑的就是这条。
  Future<void> _replaceDatabase(File target, List<int> bytes) async {
    if (!await target.parent.exists()) {
      await target.parent.create(recursive: true);
    }
    final tmp = File('${target.path}.restoring');
    await tmp.writeAsBytes(bytes, flush: true);
    try {
      await tmp.rename(target.path);
      restoreLog('atomic rename -> ${target.path}');
    } catch (e) {
      restoreLog('rename failed ($e)，退化为覆盖写');
      await target.writeAsBytes(bytes, flush: true);
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
  }

  /// 回滚：把安全副本写回去 → 重新打开 → 装回应用。
  ///
  /// 回滚本身也可能失败（磁盘满、文件被锁），此时**绝不能静默**：
  /// 把安全副本路径明确写进异常，让用户知道自己手里还有一份完整数据。
  Future<void> _rollback(
    File target,
    File safetyCopy, {
    required bool hadCurrent,
    required Object error,
  }) async {
    if (!hadCurrent) {
      // 原本没有库：删掉半成品，让应用下次启动重建空库。
      try {
        if (await target.exists()) await target.delete();
        await _deleteSidecars(target);
      } catch (e) {
        restoreLog('清理失败残留时出错: $e');
      }
      return;
    }

    try {
      final backupBytes = await safetyCopy.readAsBytes();
      await _replaceDatabase(target, backupBytes);
      final restored = await openDatabase(target);
      await _selfCheck(restored);
      await install(restored);
      restoreLog('rollback ok: ${safetyCopy.path} -> ${target.path}');
    } catch (e) {
      restoreLog('ROLLBACK FAILED: $e');
      throw RestoreException(
        '恢复失败，且自动回滚也失败了：$e\n\n'
        '你的原始数据仍完整保存在：\n${safetyCopy.path}\n'
        '请勿删除该文件。',
      );
    }
  }

  Future<void> _deleteSidecars(File target) async {
    for (final suffix in const ['-wal', '-shm']) {
      final side = File('${target.path}$suffix');
      try {
        if (await side.exists()) {
          await side.delete();
          restoreLog('deleted sidecar ${p.basename(side.path)}');
        }
      } catch (e) {
        restoreLog('delete sidecar ${p.basename(side.path)} failed: $e');
      }
    }
  }
}
