import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/database_provider.dart';
import '../application/export_backup.dart';

/// 备份导出器（绑定真实数据库）。
final backupExporterProvider = Provider<BackupExporter>((ref) {
  return BackupExporter.forDatabase(ref.watch(databaseProvider));
});

/// 调系统分享面板。
///
/// 抽成独立函数而不是直接写进页面：分享失败要能给出**可读原因**，
/// 而不是一个红色 SnackBar 里塞着 `PlatformException(...)`。
Future<void> shareBackupFile(BackupResult result) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(result.file.path, mimeType: 'application/zip')],
      subject: '效率工具数据备份',
      text: '效率工具数据备份（${result.fileName} · ${formatBackupBytes(result.bytes)}）',
    ),
  );
}
