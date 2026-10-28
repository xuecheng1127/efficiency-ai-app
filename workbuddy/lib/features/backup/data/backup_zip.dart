import 'dart:convert';

import 'package:archive/archive.dart';

/// 备份包的格式版本（与数据库 schemaVersion 分开：一个是文件格式，一个是表结构）。
const int kBackupFormatVersion = 1;

/// ZIP 内各文件的固定名字（恢复端按名字找，不按顺序猜）。
abstract final class BackupEntries {
  static const String manifest = 'manifest.json';
  static const String database = 'efficiency_app.sqlite';
  static const String databaseWal = 'efficiency_app.sqlite-wal';
  static const String settings = 'app_settings.json';
}

/// 把「文件名 → 字节」打成 ZIP。
///
/// 抽成**顶层纯函数**的两个理由：
/// 1. 可以在 `Isolate.run` 里跑（不捕获 State / BuildContext，压缩大文件不卡 UI）；
/// 2. 单测可以直接喂假字节，不需要真机、不需要数据库。
List<int> encodeBackupZip(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final bytes = entry.value;
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  // archive 的 encode 返回可空（内部 IO 错误时），这里当失败处理而不是吞掉。
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('ZIP 编码失败');
  }
  return encoded;
}

/// 生成 manifest（人可读，恢复时用来校验版本与来源）。
String buildBackupManifest({
  required DateTime exportedAt,
  required int schemaVersion,
  required Map<String, int> entrySizes,
  required String appVersion,
}) {
  return const JsonEncoder.withIndent('  ').convert({
    'format': 'efficiency_app_backup',
    'formatVersion': kBackupFormatVersion,
    'appVersion': appVersion,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'entries': [
      for (final e in entrySizes.entries) {'name': e.key, 'bytes': e.value},
    ],
  });
}
