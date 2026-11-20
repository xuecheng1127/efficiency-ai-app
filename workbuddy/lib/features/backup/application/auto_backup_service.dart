import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/settings/app_settings.dart';
import 'export_backup.dart';

/// 自动备份的持久化键（与任务书同名）。
///
/// 本工程**没有** `shared_preferences` 依赖（见 `app_settings.dart` 文件头），
/// 这两个键落在 `app_settings.json` 里 —— 语义与 SharedPreferences 一致
/// （int 毫秒时间戳 + bool），并且随备份包一起走。
abstract final class AutoBackupKeys {
  /// 上次自动备份时间（millisecondsSinceEpoch）
  static const String lastAt = 'last_auto_backup_at';

  /// 自动备份总开关（默认 true）
  static const String enabled = 'auto_backup_enabled';
}

/// 裁剪逻辑的最小输入：一份备份只需要「名字 + 修改时间」。
///
/// 为什么不是直接吃 `File`：纯函数要能在单测里跑，创建真文件既慢又要处理
/// 临时目录清理；把 IO 留在 [AutoBackupService.maybeBackup] 里，判断逻辑
/// 就变成对一个列表排序 —— 这类逻辑正是最容易写错、最该有测试的部分。
@immutable
class AutoBackupFile {
  const AutoBackupFile({required this.name, required this.modified});

  final String name;
  final DateTime modified;

  @override
  String toString() => 'AutoBackupFile($name, $modified)';
}

/// 一次自动备份的结果。`created == false && error == null` 表示「按策略跳过」。
class AutoBackupResult {
  const AutoBackupResult({
    required this.created,
    this.keptCount = 0,
    this.zipName,
    this.keptNames = const <String>[],
    this.error,
  });

  /// 本次是否真的写了新 ZIP
  final bool created;

  /// 轮转后**实际留在磁盘上**的份数
  final int keptCount;

  /// 本次新文件的名字（跳过了就是 null）
  final String? zipName;

  /// 留存下来的文件名（新的在前）—— 验收「只保留 4 份」时直接核对这个
  final List<String> keptNames;

  /// 失败原因（没有失败就是 null）
  final String? error;

  bool get skipped => !created && error == null;

  @override
  String toString() =>
      'AutoBackupResult(created: $created, kept: $keptCount, '
      'zip: $zipName, error: $error)';
}

/// 纯函数：是否到了该自动备份的时间。
///
/// 从未备份过 → 该备份；距上次达到 [intervalDays] 天 → 该备份。
/// 用 `inDays`（向下取整）而不是 `>= 7*24h`：用户看到的「8 天前」和这里判断
/// 的口径必须是同一个，否则会出现「设置页说该备份了，实际却没备」。
bool shouldAutoBackup(DateTime? lastAt, DateTime now, {int intervalDays = 7}) {
  if (lastAt == null) return true;
  return now.difference(lastAt).inDays >= intervalDays;
}

/// 纯函数：轮转裁剪 —— 按修改时间从新到旧，只保留前 [keep] 份。
///
/// 返回**应保留**的列表（新的在前），调用方负责删掉不在里面的文件。
/// 修改时间相同时按文件名倒序（文件名里带 `yyyyMMdd_HHmmss`，等价于按时间排），
/// 保证同样的输入永远得到同样的结果 —— 否则「保留哪 4 份」会变成随机的。
List<AutoBackupFile> pruneAutoBackups(List<AutoBackupFile> files, int keep) {
  if (keep <= 0) return const <AutoBackupFile>[];
  final sorted = [...files]
    ..sort((a, b) {
      final byTime = b.modified.compareTo(a.modified);
      return byTime != 0 ? byTime : b.name.compareTo(a.name);
    });
  return sorted.take(keep).toList();
}

/// 纯函数：设置页那句「上次备份」的文案。
///
/// 按**日历天**算而不是按经过小时数：23:00 备份、次日 10:00 打开设置页，
/// 用户的直觉是「昨天」，`inDays` 却会给出 0 天（11 小时）→ 说成「今天」。
String autoBackupStatusLabel(DateTime? lastAt, DateTime now) {
  if (lastAt == null) return '尚未备份过';
  final lastDay = DateTime(lastAt.year, lastAt.month, lastAt.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(lastDay).inDays;
  if (days <= 0) return '今天刚备份过';
  if (days == 1) return '上次备份：昨天';
  return '上次备份：$days 天前';
}

/// ============================================================================
/// 自动备份（7 天间隔 · 保留 4 份）
/// ============================================================================
///
/// 与「手动导出」共用同一条导出链路（[BackupExporter]）：wal_checkpoint →
/// 打包库 + 设置 + manifest → 写盘。区别只有两处：
/// 1. 文件名前缀是 `auto_backup_`，轮转只认这个前缀；
/// 2. 备份完成后把时间戳写回设置，供下次判断与设置页展示。
///
/// **依赖全部注入**（exporter / 读写设置 / 时钟）：这样单测可以用临时目录 +
/// 固定时钟跑完整流程，不需要设备、不需要 Riverpod。轮转扫描的是「新文件所在
/// 目录」，所以不需要再单独注入一个目录 —— 两个目录一旦不一致，就会出现
/// 「备份写在这里、轮转删那里」的事故。
class AutoBackupService {
  AutoBackupService({
    required BackupExporter exporter,
    required Future<AppSettings> Function() readSettings,
    required Future<void> Function({int? lastAutoBackupAt})
    writeLastAutoBackupAt,
    DateTime Function() clock = DateTime.now,
    this.intervalDays = defaultIntervalDays,
    this.keepCount = defaultKeepCount,
  }) : _exporter = exporter,
       _readSettings = readSettings,
       _writeLastAutoBackupAt = writeLastAutoBackupAt,
       _clock = clock;

  /// 自动备份间隔（天）
  static const int defaultIntervalDays = 7;

  /// 保留份数
  static const int defaultKeepCount = 4;

  final BackupExporter _exporter;
  final Future<AppSettings> Function() _readSettings;
  final Future<void> Function({int? lastAutoBackupAt}) _writeLastAutoBackupAt;
  final DateTime Function() _clock;
  final int intervalDays;
  final int keepCount;

  /// 同一次启动里 postFrame 与「回到前台」可能同时触发，必须串行化：
  /// 两个导出同时跑会各自 checkpoint 一次、各自轮转一次，最后互相删文件。
  Future<AutoBackupResult>? _inFlight;

  /// 入口：开关关闭 / 未到间隔 → 直接跳过（不写盘、不改时间戳）。
  Future<AutoBackupResult> maybeBackup({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;

    final task = _run(force: force);
    _inFlight = task;
    return task.whenComplete(() => _inFlight = null);
  }

  Future<AutoBackupResult> _run({required bool force}) async {
    final now = _clock();
    try {
      final settings = await _readSettings();
      if (!force && !settings.autoBackupEnabled) {
        debugPrint('[AutoBackup] skipped: disabled');
        return const AutoBackupResult(created: false);
      }

      final lastAt = settings.lastAutoBackupAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(settings.lastAutoBackupAt!);
      if (!force &&
          !shouldAutoBackup(lastAt, now, intervalDays: intervalDays)) {
        debugPrint('[AutoBackup] skipped: within interval');
        return const AutoBackupResult(created: false);
      }

      final exported = await _exporter.export(
        now: now,
        fileNamePrefix: kAutoBackupPrefix,
      );

      final kept = await _rotate(exported.file);

      await _writeLastAutoBackupAt(
        lastAutoBackupAt: now.millisecondsSinceEpoch,
      );

      debugPrint(
        '[AutoBackup] created ${exported.fileName} kept=${kept.length}',
      );
      return AutoBackupResult(
        created: true,
        keptCount: kept.length,
        zipName: exported.fileName,
        keptNames: kept,
      );
    } catch (e) {
      // 失败**不写**时间戳：否则一次磁盘写满就会让用户白等 7 天。
      debugPrint('[AutoBackup] failed: $e');
      return AutoBackupResult(created: false, error: e.toString());
    }
  }

  /// 轮转：只处理 `auto_backup_*.zip`，手动导出的包不在候选集里。
  ///
  /// 返回留存下来的文件名（新的在前）。
  Future<List<String>> _rotate(File newest) async {
    final dir = newest.parent;
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync();
    } catch (_) {
      // 目录都读不了就别删任何东西，至少保住刚写出来的那一份。
      return [p.basename(newest.path)];
    }

    final candidates = <AutoBackupFile>[];
    final byName = <String, File>{};
    for (final entity in entries) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      // startsWith + endsWith 双重约束：`auto_backup_old.zip.bak` 这种备份残留
      // 不该被当成备份来轮转（删错文件是不可逆的）。
      if (!name.startsWith(kAutoBackupPrefix) || !name.endsWith('.zip')) {
        continue;
      }
      byName[name] = entity;
      candidates.add(AutoBackupFile(name: name, modified: _modifiedAt(entity)));
    }

    final kept = pruneAutoBackups(candidates, keepCount);
    final keepNames = kept.map((e) => e.name).toSet();
    for (final name in byName.keys) {
      if (keepNames.contains(name)) continue;
      try {
        await byName[name]!.delete();
      } catch (e) {
        // 单个旧文件删不掉不该让整次备份失败：新包已经落盘，用户的最近一份
        // 一定是安全的。下一轮还会再尝试删。
        debugPrint('[AutoBackup] rotate delete failed: $name ($e)');
      }
    }
    return kept.map((e) => e.name).toList();
  }

  static DateTime _modifiedAt(File file) {
    try {
      return file.lastModifiedSync();
    } catch (_) {
      // 读不到时间就当「最旧」：宁可多留一轮，也不要把刚写的删掉。
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }
}
