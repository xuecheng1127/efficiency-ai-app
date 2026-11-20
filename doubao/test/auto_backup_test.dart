import 'dart:io';

import 'package:efficiency_app/core/services/auto_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// R2：自动备份轮转裁剪纯函数验证
void main() {
  test('pruneOldest 保留最近 4 份，排除最旧的 1 份', () async {
    final dir = await Directory.systemTemp.createTemp('autobackup_test');
    final now = DateTime.now();
    final files = <File>[];
    for (var i = 0; i < 5; i++) {
      final f = File('${dir.path}/efficiency_auto_backup_$i.zip');
      await f.writeAsBytes([i]);
      // i=0 最新，i=4 最旧
      await f.setLastModified(now.subtract(Duration(hours: i)));
      files.add(f);
    }

    final kept = AutoBackupService.instance.pruneOldest(files, 4);

    expect(kept.length, 4);
    final keptPaths = kept.map((f) => f.path).toSet();
    // 最旧的 i=4 被排除，最新的 i=0 保留
    expect(keptPaths, isNot(contains(files[4].path)));
    expect(keptPaths, contains(files[0].path));

    await dir.delete(recursive: true);
  });

  test('文件数不超过 keep 时全部保留', () async {
    final dir = await Directory.systemTemp.createTemp('autobackup_test2');
    final files = <File>[];
    for (var i = 0; i < 3; i++) {
      final f = File('${dir.path}/efficiency_auto_backup_$i.zip');
      await f.writeAsBytes([i]);
      files.add(f);
    }

    final kept = AutoBackupService.instance.pruneOldest(files, 4);
    expect(kept.length, 3);

    await dir.delete(recursive: true);
  });

  test('缺少文件（读取时间失败）不抛异常，按最早时间兜底', () {
    final missing = [File('nonexistent_a.zip'), File('nonexistent_b.zip')];
    final kept = AutoBackupService.instance.pruneOldest(missing, 1);
    expect(kept.length, 1);
  });

  test('shouldBackup：从未备份视为到点', () {
    final now = DateTime(2026, 11, 19, 12);
    expect(AutoBackupService.shouldBackup(null, now, 7), isTrue);
  });

  test('shouldBackup：6 天内未到间隔不备份，7 天及以上触发', () {
    final now = DateTime(2026, 11, 19, 12);
    expect(AutoBackupService.shouldBackup(now.subtract(const Duration(days: 6)), now, 7), isFalse);
    expect(AutoBackupService.shouldBackup(now.subtract(const Duration(days: 7)), now, 7), isTrue);
    expect(AutoBackupService.shouldBackup(now.subtract(const Duration(days: 8)), now, 7), isTrue);
    expect(AutoBackupService.shouldBackup(now, now, 7), isFalse);
  });
}
