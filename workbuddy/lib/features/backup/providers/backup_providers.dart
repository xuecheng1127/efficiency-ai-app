import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/platform/alarm_channel.dart';
import '../../../core/settings/app_settings.dart';
import '../../alarm/alarm_log.dart';
import '../../task/data/task_repository_impl.dart';
import '../application/auto_backup_service.dart';
import '../application/export_backup.dart';
import '../application/restore_backup.dart';

/// 备份导出器（绑定真实数据库）。
final backupExporterProvider = Provider<BackupExporter>((ref) {
  return BackupExporter.forDatabase(ref.watch(databaseProvider));
});

/// 备份包校验器（只解压 + 校验，不动任何数据）。
///
/// 用 `AppDatabase.currentSchemaVersion` 而不是 `db.schemaVersion`：
/// 校验发生在「还没决定是否覆盖」之前，不该为了读一个常量去依赖数据库实例。
final backupInspectorProvider = Provider<BackupInspector>((ref) {
  return BackupInspector(schemaVersion: AppDatabase.currentSchemaVersion);
});

/// 恢复器（真正写盘的那一层）。
///
/// 每个回调都**在调用时**才 `ref.read` 当前数据库，而不是在 Provider 构建时
/// 捕获：恢复过程中实例会被换掉，构建期捕获会拿到已 close 的旧连接。
final restoreBackupProvider = Provider<RestoreBackup>((ref) {
  AppDatabase current() => ref.read(databaseProvider);

  return RestoreBackup(
    // checkpoint 必须走正在使用的那个连接，否则 PRAGMA 作用不到真库上。
    checkpoint: () =>
        current().customSelect('PRAGMA wal_checkpoint(FULL)').get(),
    closeCurrent: () => current().close(),
    openDatabase: (file) => AppDatabase.open(file: file),
    install: (db) async {
      // 1) 换掉全局实例：所有 watch databaseProvider 的仓库/流会自动重建，
      //    界面直接显示恢复后的数据（不需要重启 App）。
      ref.read(databaseProvider.notifier).replace(db);
      // 2) 恢复出来的库可能缺今天的实例（备份是几天前导的），补齐。
      await TaskRepositoryImpl(db).backfill(DateTime.now());
      // 3) 原生闹钟层读的是同一个 sqlite 文件，文件换了要让它重新读一遍
      //    （否则原生侧还握着被替换掉的旧 inode）。失败不影响恢复结果。
      try {
        await AlarmScheduler.rescheduleAll();
        alarmNativeLog('restore: rescheduleAll invoked after database restore');
      } catch (e) {
        alarmNativeLog('restore: rescheduleAll failed (ignored): $e');
      }
    },
    databaseFile: AppDatabase.defaultFile,
    schemaVersion: AppDatabase.currentSchemaVersion,
  );
});

/// 自动备份服务：7 天一次、保留 4 份、只轮转 `auto_backup_` 前缀。
///
/// 设置在**调用时**才读（`ref.read`），不在 Provider 构建时捕获：
/// 开关刚被用户关掉的那一刻，服务拿到的必须是关掉之后的值。
final autoBackupServiceProvider = Provider<AutoBackupService>((ref) {
  return AutoBackupService(
    exporter: ref.read(backupExporterProvider),
    readSettings: () async => ref.read(appSettingsProvider),
    writeLastAutoBackupAt: ({int? lastAutoBackupAt}) async {
      await ref
          .read(appSettingsProvider.notifier)
          .patch(lastAutoBackupAt: lastAutoBackupAt);
    },
  );
});

/// 调系统分享面板。///
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
