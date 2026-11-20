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

/// ============================================================================
/// 恢复端：解码 + 校验
/// ============================================================================
///
/// 与 [encodeBackupZip] 对称，同样放在 data 层、写成**不碰文件系统**的纯函数：
/// 校验规则（头、版本）能被单测直接喂字节验证，不需要造真 zip、也不需要设备。

/// SQLite 文件头：前 15 个可见字符 + 1 个 `\0`（共 16 字节）。
const String kSqliteHeader = 'SQLite format 3';

/// 数据库文件头里 `user_version` 的位置（offset 60，4 字节 big-endian）。
const int kSqliteUserVersionOffset = 60;

/// 头 + 版本所需的**最小**长度：少了 4 字节就说明文件被截断。
const int kSqliteHeaderMinBytes = kSqliteUserVersionOffset + 4;

/// 文件是否以 SQLite 头开始（改后缀的 txt、被截断的包在这里就被挡住）。
///
/// 只看那 16 个字节，**不**要求长度到 64：短文件要报「不完整」而不是
/// 「不是数据库」—— 两种错法对用户的意义完全不同（一个是被改过，
/// 一个是没下载完/被截断）。
bool hasSqliteHeader(List<int> bytes) {
  if (bytes.length < kSqliteHeader.length + 1) return false;
  for (var i = 0; i < kSqliteHeader.length; i++) {
    if (bytes[i] != kSqliteHeader.codeUnitAt(i)) return false;
  }
  // 第 16 个字节必须是 NUL；不是的话更可能是「文本里恰好有这几个字母」。
  return bytes[kSqliteHeader.length] == 0;
}

/// 读 SQLite 头里的 `user_version`（drift 的 schemaVersion 就存在这里）。
///
/// 为什么不用 `PRAGMA user_version`：恢复前我们**不能**打开那个文件
/// （drift 一打开就可能跑迁移，把「来自新版本的库」当旧库升掉），
/// 只能读文件头。长度为 64 字节的偏移是 SQLite 文件格式固定的。
int? readSqliteUserVersion(List<int> bytes) {
  if (bytes.length < kSqliteHeaderMinBytes) return null;
  const o = kSqliteUserVersionOffset;
  return (bytes[o] << 24) |
      (bytes[o + 1] << 16) |
      (bytes[o + 2] << 8) |
      bytes[o + 3];
}

/// manifest 里恢复端真正用得上的字段（其余键忽略，向后兼容）。
class BackupManifestInfo {
  const BackupManifestInfo({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
  });

  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final DateTime? exportedAt;

  /// 容错解析：manifest 只是「人可读的旁证」，坏了不该让恢复失败 ——
  /// 真正的判据永远是数据库文件头（[readSqliteUserVersion]）。
  static BackupManifestInfo? tryParse(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      return BackupManifestInfo(
        formatVersion: decoded['formatVersion'] is int
            ? decoded['formatVersion'] as int
            : 0,
        schemaVersion: decoded['schemaVersion'] is int
            ? decoded['schemaVersion'] as int
            : 0,
        appVersion: decoded['appVersion'] is String
            ? decoded['appVersion'] as String
            : '未知',
        exportedAt: DateTime.tryParse('${decoded['exportedAt']}'),
      );
    } catch (_) {
      return null;
    }
  }
}

/// 解出来的备份包（只做格式层面的解压，不做业务判断）。
class BackupContents {
  const BackupContents({required this.entries, required this.manifest});

  final Map<String, List<int>> entries;
  final BackupManifestInfo? manifest;

  List<int>? operator [](String name) => entries[name];
}

/// 解开 ZIP；不是合法 ZIP 时抛 [FormatException]（由调用方翻译成人话）。
///
/// 抽成顶层纯函数：可以进 `Isolate.run`，也可以被单测直接调用。
BackupContents decodeBackupZip(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on FormatException {
    rethrow;
  } catch (e) {
    // archive 对「不是 zip」会抛 ArchiveException / RangeError 等，
    // 统一收敛成 FormatException，让上层只需要认一种类型。
    throw FormatException('不是合法的 ZIP 文件：$e');
  }

  final entries = <String, List<int>>{};
  for (final file in archive.files) {
    if (!file.isFile) continue;
    final content = file.content;
    if (content is List<int>) {
      entries[file.name] = content;
    }
  }

  final manifestBytes = entries[BackupEntries.manifest];
  return BackupContents(
    entries: entries,
    manifest: manifestBytes == null
        ? null
        : BackupManifestInfo.tryParse(manifestBytes),
  );
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
