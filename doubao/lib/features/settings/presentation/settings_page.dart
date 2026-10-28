import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/alarm_service.dart';
import '../../task/providers/task_providers.dart';
import '../providers/settings_provider.dart';

/// 全局设置页（模块5 P0）
///
/// 分类展示：通用设置 / 提醒设置 / 外观设置 / 数据与备份。
/// V1.0 基础版实现：主题模式切换（浅色/深色/跟随系统）、任务提醒总开关。
/// 数据备份与恢复在后续迭代接入。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _exportData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('正在打包数据...'), duration: Duration(seconds: 2)),
      );

      // 1. checkpoint 数据库（失败不阻断导出）
      try {
        final db = AppDatabase.instance;
        await db.customStatement('PRAGMA wal_checkpoint(FULL)');
      } catch (e) {
        debugPrint('checkpoint failed: $e');
      }

      // 2. 找到数据库文件
      final supportDir = await getApplicationSupportDirectory();
      final dbFile = File(p.join(supportDir.path, 'efficiency_app.sqlite'));
      debugPrint('db file: ${dbFile.path}, exists=${await dbFile.exists()}');

      // 3. 打包 zip
      final archive = Archive();
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('efficiency_app.sqlite', dbBytes.length, dbBytes));

      final zipData = ZipEncoder().encode(archive);

      // 4. 写到应用文档目录
      final docDir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now();
      final stamp = '${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}';
      final zipPath = p.join(docDir.path, 'efficiency_backup_$stamp.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData, flush: true);
      debugPrint('zip written: $zipPath, size=${await zipFile.length()}');

      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('已导出到: $zipPath (${(zipData.length / 1024).toStringAsFixed(1)} KB)'),
          action: SnackBarAction(
            label: '分享',
            onPressed: () => Share.shareXFiles([XFile(zipPath)], text: '效率助手数据备份'),
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    } catch (e, st) {
      debugPrint('export failed: $e\n$st');
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('导出失败: $e'), duration: const Duration(seconds: 5)));
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 1. 选 zip 文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final bytes = picked.bytes;
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('读取文件失败')));
        return;
      }

      // 2. 解 zip
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        messenger.showSnackBar(const SnackBar(content: Text('文件格式不对，不是有效 ZIP')));
        return;
      }

      // 3. 找 sqlite 文件
      ArchiveFile? dbFile;
      for (final f in archive.files) {
        if (f.name.endsWith('.sqlite') || f.name.endsWith('.db')) {
          dbFile = f;
          break;
        }
      }
      if (dbFile == null) {
        messenger.showSnackBar(const SnackBar(content: Text('备份里没有数据库文件')));
        return;
      }

      // 4. 校验 SQLite 头
      final dbBytes = dbFile.content as List<int>;
      final header = String.fromCharCodes(dbBytes.take(16));
      if (!header.startsWith('SQLite format 3')) {
        messenger.showSnackBar(const SnackBar(content: Text('备份文件损坏：不是有效的 SQLite 数据库')));
        return;
      }

      // 4.1 校验 schema 版本（SQLite 头 offset 60-63 big-endian）
      try {
        final uver = ByteData.sublistView(Uint8List.fromList(dbBytes), 60, 64).getUint32(0);
        if (uver > AppDatabase.instance.schemaVersion) {
          messenger.showSnackBar(
            SnackBar(content: Text('备份来自更新版本 (v$uver)，当前版本 (v${AppDatabase.instance.schemaVersion}) 无法恢复')),
          );
          return;
        }
      } catch (_) {}

      // 5. 二次确认
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('确认恢复？'),
          content: Text(
            '备份文件：${picked.name}\n'
            '大小：${(dbBytes.length / 1024).toStringAsFixed(1)} KB\n\n'
            '这会覆盖当前所有数据！建议先导出当前数据。',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('确认恢复', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (ok != true) return;

      // 6. checkpoint + 备份 + 关闭 + 清理 sidecar + 替换 + 校验 + 回滚
      messenger.showSnackBar(const SnackBar(content: Text('正在恢复...'), duration: Duration(seconds: 2)));
      final supportDir = await getApplicationSupportDirectory();
      final dbPath = p.join(supportDir.path, 'efficiency_app.sqlite');
      final dbFileObj = File(dbPath);
      final bakPath = '$dbFileObj.pre_restore.bak';

      // 6.1 先 checkpoint，把 WAL 刷进主库
      try {
        await AppDatabase.instance.customStatement('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      // 6.2 再备份当前库
      if (await dbFileObj.exists()) {
        await dbFileObj.copy(bakPath);
      }

      // 6.3 关闭 DB
      await AppDatabase.instance.close();

      // 6.4 清理旧 sidecar（-wal / -shm），防止污染新库
      for (final suffix in ['-wal', '-shm']) {
        final f = File('$dbPath$suffix');
        if (await f.exists()) await f.delete();
      }

      // 6.5 写入新库
      try {
        await File(dbPath).writeAsBytes(dbBytes, flush: true);
      } catch (e) {
        // 写失败：回滚
        if (await File(bakPath).exists()) await File(bakPath).copy(dbPath);
        rethrow;
      }

      // 6.6 试探性打开新库；失败则回滚
      bool rollback = false;
      try {
        // 重新打开（单例已 close，重新构造）
        // 这里简单做：直接检查文件头
        final head = await File(dbPath).openRead().take(16).first;
        if (!String.fromCharCodes(head).startsWith('SQLite format 3')) {
          rollback = true;
        }
      } catch (_) {
        rollback = true;
      }

      if (rollback) {
        if (await File(bakPath).exists()) {
          await File(bakPath).copy(dbPath);
        }
        // 清理 sidecar
        for (final suffix in ['-wal', '-shm']) {
          final f = File('$dbPath$suffix');
          if (await f.exists()) await f.delete();
        }
        if (!context.mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('备份不兼容，已回滚到原数据')),
        );
        return;
      }

      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      // 重建单例，下次访问自动打开新库
      AppDatabase.resetInstance();
      messenger.showSnackBar(
        const SnackBar(content: Text('恢复成功，数据已重载'), duration: Duration(seconds: 5)),
      );
    } catch (e, st) {
      debugPrint('restore failed: $e\n$st');
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final logFile = File(p.join(docDir.path, 'restore_error.log'));
        await logFile.writeAsString('$e\n$st\n', mode: FileMode.append);
      } catch (_) {}
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('恢复失败: $e'), duration: const Duration(seconds: 5)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('设置加载失败，请重启应用', style: TextStyle(fontSize: 16)),
        ),
        data: (s) => ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppColors.pagePadding),
          children: [
            // ---- 通用设置 ----
            const _SectionHeader('通用设置'),
            _Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('外观'),
                    trailing: DropdownButton<ThemeMode>(
                      value: s.themeMode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('跟随系统'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('浅色'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('深色'),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .setThemeMode(mode);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.repeat_outlined),
                    title: const Text('新任务默认重复规则'),
                    trailing: DropdownButton<int>(
                      value: s.defaultRepeatRule,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('单次')),
                        DropdownMenuItem(value: 1, child: Text('每日重复')),
                        DropdownMenuItem(value: 2, child: Text('每周重复')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .setDefaultRepeatRule(v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- 提醒设置 ----
            const _SectionHeader('提醒设置'),
            _Card(
              child: Column(
                children: [
                  // T18: 闹钟档位显示（A 精确 / B 近似 / C 应用内）
                  FutureBuilder<bool>(
                    future: AlarmService.instance.canScheduleExactAlarms(),
                    builder: (context, snapshot) {
                      final canExact = snapshot.data ?? false;
                      final tier = canExact ? 'A · 精确闹钟' : 'B · 近似闹钟';
                      final tierColor = canExact ? AppColors.success : AppColors.warning;
                      final tierDesc = canExact
                          ? '闹钟将准时响铃'
                          : '未授权精确闹钟，系统可能延迟几分钟响铃';
                      return ListTile(
                        leading: Icon(
                          canExact ? Icons.alarm_on : Icons.alarm,
                          color: tierColor,
                        ),
                        title: Text('当前闹钟档位：$tier'),
                        subtitle: Text(tierDesc),
                        trailing: canExact
                            ? null
                            : TextButton(
                                onPressed: () async {
                                  await AlarmService.instance.requestExactAlarmPermission();
                                },
                                child: const Text('去开启'),
                              ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.alarm_outlined),
                    title: const Text('任务提醒总开关'),
                    subtitle: const Text('关闭后所有任务闹钟不再响铃'),
                    value: s.taskReminderEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) async {
                      await ref
                          .read(settingsProvider.notifier)
                          .setTaskReminderEnabled(v);
                      // 联动：关闭 → 取消全部闹钟；开启 → 全量重排
                      await _resyncAllAlarms(ref);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.snooze_outlined),
                    title: const Text('贪睡模式'),
                    subtitle: const Text('响铃后可贪睡（最多 3 次）'),
                    value: s.snoozeEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) async {
                      await ref
                          .read(settingsProvider.notifier)
                          .setSnoozeEnabled(v);
                      await _resyncAllAlarms(ref);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('贪睡间隔'),
                    trailing: DropdownButton<int>(
                      value: s.snoozeMinutes,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('3 分钟')),
                        DropdownMenuItem(value: 5, child: Text('5 分钟')),
                        DropdownMenuItem(value: 10, child: Text('10 分钟')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        await ref
                            .read(settingsProvider.notifier)
                            .setSnoozeMinutes(v);
                        await _resyncAllAlarms(ref);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.music_note_outlined),
                    title: const Text('闹钟铃音'),
                    subtitle: const Text('轻柔纯音乐，前 3 秒渐强'),
                    trailing: DropdownButton<String>(
                      value: AlarmService.builtInRingtones.contains(s.alarmRingtone)
                          ? s.alarmRingtone
                          : '晨曦',
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final tone in AlarmService.builtInRingtones)
                          DropdownMenuItem(
                            value: tone,
                            child: Text('内置 · $tone'),
                          ),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        await ref
                            .read(settingsProvider.notifier)
                            .setAlarmRingtone(v);
                        await _resyncAllAlarms(ref);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.volume_up_outlined),
                    title: const Text('闹钟音量'),
                    subtitle: Text('${s.alarmVolume}%'),
                    trailing: SizedBox(
                      width: 140,
                      child: Slider(
                        value: s.alarmVolume.toDouble(),
                        min: 10,
                        max: 100,
                        divisions: 9,
                        activeColor: AppColors.primary,
                        onChanged: (v) async {
                          await ref
                              .read(settingsProvider.notifier)
                              .setAlarmVolume(v.round());
                          await _resyncAllAlarms(ref);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- 数据与备份 ----
            const _SectionHeader('数据与备份'),
            _Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: const Text('导出全部数据 (ZIP)'),
                    subtitle: const Text('打包数据库与日记，可分享或备份'),
                    onTap: () => _exportData(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restore_outlined),
                    title: const Text('从备份恢复'),
                    subtitle: const Text('从 ZIP 备份恢复数据，会覆盖当前'),
                    onTap: () => _restoreData(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- 关于 ----
            const _SectionHeader('关于'),
            _Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('效率助手 V1.2'),
                subtitle: const Text('专注 · 记录 · 成长'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 提醒设置变化后的闹钟全量联动（T01：字段来源为新模型 TaskTemplate）
  /// - 总开关关闭：取消全部任务闹钟；
  /// - 开启 / 铃音 / 音量 / 贪睡变化：遍历绑定闹钟的任务重新调度。
  Future<void> _resyncAllAlarms(WidgetRef ref) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null) return;
    final repo = ref.read(taskRepositoryProvider);
    final tasks = await repo.getAllTasks();

    final alarmService = AlarmService.instance;
    if (!settings.taskReminderEnabled) {
      for (final task in tasks) {
        if (task.alarmEnabled) {
          await alarmService.cancelTaskAlarm(task.id!);
        }
      }
      return;
    }
    for (final task in tasks) {
      if (task.alarmEnabled) {
        await alarmService.scheduleTaskAlarm(task, settings);
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        child: child,
      ),
    );
  }
}
