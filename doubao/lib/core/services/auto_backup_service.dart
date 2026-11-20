import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

/// 自动备份持久化键（SharedPreferences，不写数据库 schema）
abstract final class AutoBackupKeys {
  /// 上次自动备份时间戳（millisecondsSinceEpoch）
  static const String lastAt = 'last_auto_backup_at';

  /// 自动备份总开关（默认开启）
  static const String enabled = 'auto_backup_enabled';
}

/// 自动备份结果
class AutoBackupResult {
  /// 是否本次真正生成了新 ZIP
  final bool created;

  /// 轮转后保留的备份份数
  final int keptCount;

  /// 本次生成的备份文件名（未生成为 null）
  final String? zipName;

  /// 失败原因（未失败为 null）
  final String? error;

  const AutoBackupResult({
    required this.created,
    required this.keptCount,
    this.zipName,
    this.error,
  });

  /// 未生成且无错误：开关关闭或尚未到间隔
  bool get skipped => !created && error == null;
}

/// 自动备份服务
///
/// 策略：
/// - App 启动时检查一次，距上次备份超过 [AutoBackupService.intervalDays] 天则自动导出；
/// - 备份写入应用文档目录，文件名前缀 `efficiency_auto_backup_`；
/// - 只轮转自动备份（不动手动导出的 `efficiency_backup_*.zip`），最多保留 [keepCount] 份，
///   超出删除最旧的；
/// - 不弹系统通知，仅在前台时由界面层决定是否轻提示。
class AutoBackupService {
  AutoBackupService._();
  static final AutoBackupService instance = AutoBackupService._();

  /// 保留最近份数
  static const int keepCount = 4;

  /// 自动备份间隔（天）
  static const int intervalDays = 7;

  // ==================== 开关与时间戳 ====================

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AutoBackupKeys.enabled) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AutoBackupKeys.enabled, enabled);
  }

  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(AutoBackupKeys.lastAt);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 距上次备份的天数（不足 1 天按 0 计；从未备份返回 null）
  Future<int?> daysSinceLastBackup() async {
    final last = await lastBackupAt();
    if (last == null) return null;
    return DateTime.now().difference(last).inDays;
  }

  // ==================== 纯函数：轮转裁剪 ====================

  /// 是否到了该备份的时间（纯函数，便于单测）。
  ///
  /// 从未备份过视为到点；距上次备份达到 [intervalDays] 天视为到点。
  static bool shouldBackup(DateTime? last, DateTime now, int intervalDays) {
    if (last == null) return true;
    return now.difference(last).inDays >= intervalDays;
  }

  /// 按修改时间从新到旧排序，返回应保留的前 [keep] 份；超出的最旧文件由调用方删除。
  ///
  /// 纯函数，便于单测；不做任何文件删除/IO 副作用。
  List<File> pruneOldest(List<File> files, int keep) {
    final sorted = [...files]
      ..sort((a, b) => _mtime(b).compareTo(_mtime(a)));
    return sorted.take(keep).toList();
  }

  DateTime _mtime(File f) {
    try {
      return f.lastModifiedSync();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  // ==================== 执行备份 ====================

  /// 启动时调用：未到间隔或开关关闭则跳过；到点则打包、轮转、记录时间戳。
  Future<AutoBackupResult> maybeBackup({bool force = false}) async {
    try {
      if (!force && !await isEnabled()) {
        debugPrint('[AutoBackup] skipped: disabled');
        return const AutoBackupResult(created: false, keptCount: 0);
      }

      final last = await lastBackupAt();
      final now = DateTime.now();
      if (!force && !shouldBackup(last, now, intervalDays)) {
        debugPrint('[AutoBackup] skipped: within interval');
        return const AutoBackupResult(created: false, keptCount: 0);
      }

      final zipFile = await _exportZip();

      // 轮转：仅处理自动备份前缀
      final all = zipFile.parent
          .listSync()
          .whereType<File>()
          .where((f) =>
              p.basename(f.path).startsWith('efficiency_auto_backup_') &&
              f.path.endsWith('.zip'))
          .toList();
      final keepFiles = pruneOldest(all, keepCount);
      final keepPaths = keepFiles.map((f) => f.path).toSet();
      for (final f in all) {
        if (!keepPaths.contains(f.path)) {
          try {
            await f.delete();
          } catch (_) {
            // 单个旧文件删除失败不阻断本次备份
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AutoBackupKeys.lastAt, now.millisecondsSinceEpoch);

      debugPrint('[AutoBackup] created ${p.basename(zipFile.path)} kept=${keepFiles.length}');
      return AutoBackupResult(
        created: true,
        keptCount: keepFiles.length,
        zipName: p.basename(zipFile.path),
      );
    } catch (e) {
      debugPrint('[AutoBackup] failed: $e');
      return AutoBackupResult(created: false, keptCount: 0, error: e.toString());
    }
  }

  /// 打包当前数据库为 ZIP，写入应用文档目录并返回文件。
  Future<File> _exportZip() async {
    // 1. checkpoint，把 WAL 刷进主库（失败不阻断导出）
    try {
      await AppDatabase.instance
          .customStatement('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {}

    // 2. 读取数据库文件
    final supportDir = await getApplicationSupportDirectory();
    final dbFile = File(p.join(supportDir.path, 'efficiency_app.sqlite'));
    final dbBytes = await dbFile.readAsBytes();

    // 3. 打包 zip
    final archive = Archive();
    archive.addFile(
      ArchiveFile('efficiency_app.sqlite', dbBytes.length, dbBytes),
    );
    final zipData = ZipEncoder().encode(archive);

    // 4. 写入文档目录
    final docDir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now();
    final stamp =
        '${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}'
        '_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}'
        '${ts.second.toString().padLeft(2, '0')}';
    final zipFile =
        File(p.join(docDir.path, 'efficiency_auto_backup_$stamp.zip'));
    await zipFile.writeAsBytes(zipData, flush: true);
    return zipFile;
  }
}
