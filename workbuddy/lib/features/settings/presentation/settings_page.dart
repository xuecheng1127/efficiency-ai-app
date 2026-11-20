import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/providers/theme_provider.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_version.dart';
import '../../../core/diagnostics/startup_trace.dart';
import '../../../core/platform/alarm_channel.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../backup/application/auto_backup_service.dart';
import '../../backup/application/export_backup.dart';
import '../../backup/application/restore_backup.dart';
import '../../backup/providers/backup_providers.dart';
import '../../search/presentation/search_page.dart';
import '../../widget/data/today_widget_sync.dart';
import '../../widget/providers/today_widget_providers.dart';
import '../providers/reminder_switch.dart';

/// ============================================================================
/// 设置页（重写版）
/// ============================================================================
///
/// 设计约束来自《UI 验收标准》：
/// - R1 禁止假控件：「导出全部数据」与「从备份恢复」都是真入口
///   （恢复的完整流程见 `_restoreData`，含校验、二次确认、安全副本与回滚）；
/// - D1 卡片分组 / D2 每行图标 / D3 每行说明：一律走 `AppSectionHeader` +
///   `AppCard.group` + `ui_kit` 的行组件，天然满足；
/// - D4 状态颜色：闹钟档位用 [AppStatusTile]（绿=精确档 / 橙=近似档）；
/// - D5 行动入口：未授权时给「去开启」按钮；
/// - D6 操作反馈：开关 / 下拉 / 音量落库后都有 SnackBar；
/// - D7 一致性：间距、圆角、颜色只取 [AppDimens] 与 Theme。
///
/// 每个控件「点了之后到底发生了什么」，见各 handler 的注释。
/// ============================================================================

/// 精确闹钟权限（A 档 / B 档）的读取结果。
///
/// 抽成 `FutureProvider` 的三个理由：
/// 1. 每次进页面都重新探测真实权限，不缓存一个可能已经过时的结论；
/// 2. 页面用 `AsyncValue` 就能覆盖「加载 / 错误 / 数据」三态（R3）；
/// 3. 下拉刷新只需 `ref.invalidate` 这一处，不用页面自己维护半套状态。
final _exactAlarmProvider = FutureProvider<bool>((ref) {
  return AlarmScheduler.canScheduleExactAlarms();
});

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver {
  /// 音量的拖动草稿：拖动过程中只改本地 state，松手才落库。
  /// 为什么不用 `ref.watch` 直接驱动：每移动一格都写一次 JSON 文件没有意义，
  /// 而且会让滑块跟着异步回写抖动。
  int? _volumeDraft;

  /// 导出中：防连点，同时给行尾一个进度圈（点了必须有反馈）。
  bool _exporting = false;

  /// 恢复中：同上。恢复比导出更重（要关连接、换文件、重开），
  /// 期间必须挡住第二次点击，否则两条恢复会互相踩文件。
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 用户点「去开启」跳到系统设置、开完权限回来的那一刻自动复检一次，
  /// 否则卡片会停留在「近似档」，看起来像没生效。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(_exactAlarmProvider);
    }
  }

  /// 下拉刷新：重新读一次系统权限。
  Future<void> _refreshExactAlarm() async {
    ref.invalidate(_exactAlarmProvider);
    try {
      await ref.read(_exactAlarmProvider.future);
    } catch (_) {
      // 失败本身由错误态的卡片呈现（R3），这里只负责结束下拉动画。
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 「去开启」：真正跳系统设置页，并如实反馈「跳没跳成功」。
  Future<void> _requestExactAlarm() async {
    try {
      await AlarmScheduler.requestExactAlarmPermission();
      if (!mounted) return;
      _toast('已打开系统设置：找到「闹钟和提醒」并允许后返回本页');
      ref.invalidate(_exactAlarmProvider);
    } catch (_) {
      _toast('无法打开系统设置：当前设备未接入闹钟原生通道');
    }
  }

  /// 任务提醒总开关：走 [ReminderSwitch]，真的会取消 / 重排系统侧闹钟。
  Future<void> _toggleReminders(bool enabled) async {
    final ok = await ref.read(reminderSwitchProvider).setEnabled(enabled);
    if (ok) {
      _toast(enabled ? '已开启：所有任务闹钟会正常响铃' : '已关闭：全部闹钟已取消，重启后也不会响');
    } else {
      _toast('操作失败：提醒设置没能写入，请重试');
    }
  }

  Future<void> _setSnoozeEnabled(bool enabled, int minutes) async {
    await ref.read(appSettingsProvider.notifier).patch(snoozeEnabled: enabled);
    _toast(enabled ? '已开启贪睡：默认 $minutes 分钟后再次提醒' : '已关闭贪睡：闹钟不会再二次提醒');
  }

  /// 导出全部数据：wal_checkpoint → 打包 ZIP → 写文档目录 → 提示路径/大小。
  ///
  /// 失败**不吞**：区分「数据库文件找不到」这种可解释原因与其他异常，
  /// 用户至少知道是没导出成功，而不是「点了没反应」。
  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final result = await ref.read(backupExporterProvider).export();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '已导出 ${formatBackupBytes(result.bytes)}\n${result.file.path}',
            ),
            duration: const Duration(seconds: 10),
            // Flutter 3.47 起：带 action 的 SnackBar 默认 persist=true（永不自动消失）。
            // 这里必须显式 false，否则提示会一直压住底部导航。
            persist: false,
            action: SnackBarAction(
              label: '分享',
              onPressed: () => _shareBackup(result),
            ),
          ),
        );
    } on BackupException catch (e) {
      _toast('导出失败：${e.message}');
    } catch (e) {
      _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareBackup(BackupResult result) async {
    try {
      await shareBackupFile(result);
    } catch (e) {
      _toast('无法调起系统分享：$e');
    }
  }

  /// ==========================================================================
  /// 自动备份（R3 任务 2）
  /// ==========================================================================
  ///
  /// 关掉只是「不再到点自动跑」：已经导出的 `auto_backup_*.zip` 一个都不删，
  /// 手动导出与恢复完全不受影响。开回来时顺手检查一次 —— 用户刚打开开关，
  /// 多半就是现在想要一份；未到 7 天间隔会自动跳过，不会反复重写。
  Future<void> _toggleAutoBackup(bool enabled) async {
    await ref
        .read(appSettingsProvider.notifier)
        .patch(autoBackupEnabled: enabled);

    if (!enabled) {
      _toast('已关闭自动备份：已有备份文件不会删除');
      return;
    }

    final result = await ref.read(autoBackupServiceProvider).maybeBackup();
    if (!mounted) return;
    if (result.error != null) {
      _toast('已开启，但这次备份失败：${result.error}');
    } else if (result.created) {
      _toast('已自动备份（第 ${result.keptCount} 份）：${result.zipName}');
    } else {
      _toast('已开启自动备份：每 7 天一次，最多保留 4 份');
    }
  }

  /// ==========================================================================
  /// 桌面小组件（R2）
  /// ==========================================================================
  ///
  /// 顺序很重要：**先同步、再请求添加**。
  /// 桌面确认框弹出时，系统可能立刻按 prefs 里的现有值渲染一次；
  /// 如果这时候 prefs 还是空的（比如今天是首次安装），
  /// 用户点「添加」后看到的是一张只有标题的空卡片，会以为坏了。
  Future<void> _addWidgetToHome() async {
    // 同步失败不拦：prefs 里可能已经有上一次的值，比直接不弹框好。
    await ref.read(todayWidgetSyncProvider).sync();
    final result = await requestPinTodayWidget();
    if (!mounted) return;
    switch (result) {
      case WidgetPinResult.requested:
        _toast('请在桌面弹出的提示里点「添加」');
      case WidgetPinResult.unsupported:
        _toast('当前桌面不支持一键添加，请长按桌面 →「小组件」→ 今日任务');
      case WidgetPinResult.failed:
        _toast('调起桌面添加入口失败，请长按桌面手动添加');
    }
  }

  /// ==========================================================================
  /// 从备份恢复（R2 · P0）
  /// ==========================================================================
  ///
  /// 四步，每一步都有明确的「停在哪里」：
  /// 1. 选包（file_picker）→ 2. 校验并展示包内事实（**不动数据**）
  /// → 3. 二次确认 → 4. 真正覆盖（带安全副本与自检回滚）。
  ///
  /// 为什么校验和覆盖要分成两个对象：确认弹窗必须显示「这个包到底是什么」
  /// （文件名 / 大小 / 备份时间 / 备份版本），而这些信息只能靠**先解一次包**
  /// 得到；但解包成功不等于可以立刻覆盖。用户在这一步点取消，数据必须一个字节都没动。
  Future<void> _restoreData() async {
    if (_restoring) return;

    // ---- 1. 选包 --------------------------------------------------------
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: '选择备份包（.zip）',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
    } catch (e) {
      _toast('无法打开文件选择器：$e');
      restoreLog('pickFile failed: $e');
      return;
    }
    // 用户点了取消：什么都不做，也不打扰他。
    if (picked == null) return;

    final File zip;
    try {
      zip = await _materializePickedFile(picked);
    } on RestoreException catch (e) {
      restoreLog('materialize failed: ${e.message}');
      await _showRestoreError('无法读取所选文件', e.message);
      return;
    }

    // ---- 2. 校验（只读） -------------------------------------------------
    setState(() => _restoring = true);
    BackupPreview preview;
    try {
      preview = await ref.read(backupInspectorProvider).inspect(zip);
    } on RestoreException catch (e) {
      restoreLog('inspect rejected: ${e.message}');
      if (mounted) setState(() => _restoring = false);
      await _showRestoreError('这份备份不能用', e.message);
      return;
    } catch (e) {
      restoreLog('inspect failed: $e');
      if (mounted) setState(() => _restoring = false);
      await _showRestoreError('读取备份包失败', '$e');
      return;
    }

    // ---- 3. 二次确认 -----------------------------------------------------
    if (!mounted) return;
    final confirmed = await _confirmRestore(preview);
    if (confirmed != true) {
      if (mounted) setState(() => _restoring = false);
      return;
    }

    // ---- 4. 覆盖 ---------------------------------------------------------
    // 恢复期间数据库会被关闭再打开，界面上任何依赖数据库的页都会短暂重建；
    // 用一个不可取消的遮罩挡住这段窗口，避免用户在半途操作。
    final progress = _showRestoreProgress();
    try {
      final result = await ref.read(restoreBackupProvider).restore(preview);
      restoreLog(
        'restore done: ${result.databaseFile.path} '
        'objects=${result.rows} safety=${result.safetyCopy?.path}',
      );
      if (!mounted) return;
      _dismissRestoreProgress(progress);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '已从备份恢复（${result.rows} 个数据库对象 · v${result.userVersion}）\n'
              '${result.safetyCopy == null ? '恢复前本机没有数据库，无需安全副本' : '恢复前的数据已另存：${p.basename(result.safetyCopy!.path)}'}',
            ),
            duration: const Duration(seconds: 8),
            persist: false,
          ),
        );
    } on RestoreException catch (e) {
      restoreLog('restore rejected: ${e.message}');
      if (!mounted) return;
      _dismissRestoreProgress(progress);
      await _showRestoreError('恢复失败', e.message);
    } catch (e) {
      restoreLog('restore threw: $e');
      if (!mounted) return;
      _dismissRestoreProgress(progress);
      await _showRestoreError('恢复失败', '$e');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /// 把「选中的文件」变成磁盘上真实存在的 [File]。
  ///
  /// Android 的 SAF 有时只给 `content://` URI（没有本地路径）：
  /// 这种情况下把字节落到缓存目录，后续所有逻辑就能统一按「一个文件」处理，
  /// 不用在每个环节都分支判断 URI / 路径。
  Future<File> _materializePickedFile(PlatformFile picked) async {
    final localPath = picked.path;
    if (localPath != null && localPath.isNotEmpty) return File(localPath);

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      throw const RestoreException('所选文件是空的（0 字节）。');
    }
    final dir = await getTemporaryDirectory();
    if (!dir.existsSync()) await dir.create(recursive: true);
    final file = File(
      p.join(
        dir.path,
        'restore_pick_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    restoreLog(
      'materialized content:// pick -> ${file.path} (${bytes.length} B)',
    );
    return file;
  }

  /// 确认弹窗：把包内事实摊开给用户看，并写清「会发生什么、能不能回头」。
  Future<bool?> _confirmRestore(BackupPreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('用这份备份覆盖当前数据？'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _PreviewRow(label: '备份文件', value: preview.fileName),
                _PreviewRow(label: '文件大小', value: preview.sizeLabel),
                _PreviewRow(label: '备份时间', value: preview.backedUpAtLabel),
                _PreviewRow(
                  label: '备份版本',
                  value:
                      '应用 ${preview.appVersionLabel} · 数据库 v${preview.databaseUserVersion}',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                  ),
                  child: Text(
                    '当前的任务 / 日记 / 备忘录 / 工具箱数据会被**整份替换**。\n'
                    '恢复前会自动把现有数据库复制成 .pre_restore.bak，'
                    '恢复成功后也保留这个副本，可人工找回。',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('覆盖恢复'),
            ),
          ],
        );
      },
    );
  }

  /// 不可取消的进度遮罩（恢复期间会短暂关闭数据库，不能让用户在半途操作）。
  Route<void> _showRestoreProgress() {
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RestoreProgressDialog(),
    );
    Navigator.of(context, rootNavigator: true).push(route);
    return route;
  }

  void _dismissRestoreProgress(Route<void> route) {
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (route.isActive) nav.removeRoute(route);
  }

  /// 失败详情单独一屏（可滚动、可长按复制）：恢复失败的原因往往很长
  /// （路径、SQLite 错误码、回滚结果），塞进 SnackBar 会被截断成无用的三个字。
  Future<void> _showRestoreError(String title, String detail) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: SelectableText(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    StartupTrace.markOnce('ui.tab.settings.build');
    final settings = ref.watch(appSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final volume = _volumeDraft ?? settings.volume;
    // 自动备份那行要显示「上次备份几天前」：毫秒时间戳 → DateTime，
    // 换算只在这里做一次（service 里只认 int，避免两处口径不一致）。
    final lastAutoBackupAt = settings.lastAutoBackupAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(settings.lastAutoBackupAt!);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(namesRoute: true, child: const Text('设置')),
        actions: const [SearchAction()],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshExactAlarm,
        child: ListView(
          // 内容不足一屏时也要能下拉刷新（否则「去开启后回来」没有刷新入口）。
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
          children: [
            const AppSectionHeader('通用设置', subtitle: '外观，以及新建任务的默认值'),

            // ---------------- 通用设置 ----------------
            AppCard.group(
              children: [
                _ThemeModeRow(
                  mode: themeMode,
                  onChanged: (mode) {
                    // 真实写入 app_settings.json，全局立即换主题（themeModeProvider 已持久化）。
                    ref.read(themeModeProvider.notifier).setMode(mode);
                    _toast('已切换为${_themeModeLabel(mode)}主题');
                  },
                ),
                _ChoiceTile<String>(
                  icon: Icons.repeat_rounded,
                  title: '新任务默认重复规则',
                  subtitle:
                      '新建任务时默认选中「${_repeatLabel(settings.defaultRepeatMode)}」',
                  // 与 add_task_page 的解析口径一致：只认三个小写字面量，
                  // 文件被手改坏时也按「每日」展示，不让下拉与副标题说两套话。
                  value: _validRepeat(settings.defaultRepeatMode),
                  options: const {'once': '单次', 'daily': '每日', 'weekly': '每周'},
                  onChanged: (value) async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .patch(defaultRepeatMode: value);
                    _toast('新任务的默认重复规则已设为「${_repeatLabel(value)}」');
                  },
                ),
              ],
            ),

            const AppSectionHeader('提醒设置', subtitle: '闹钟能否准时响，取决于系统权限与这里的开关'),

            // ---------------- 提醒设置 ----------------
            AppCard.group(
              children: [
                _ExactAlarmTile(
                  asyncStatus: ref.watch(_exactAlarmProvider),
                  onRequestPermission: _requestExactAlarm,
                  onRetry: _refreshExactAlarm,
                ),
                AppSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: '任务提醒总开关',
                  value: settings.remindersEnabled,
                  onChanged: _toggleReminders,
                  subtitle: '关闭后所有任务闹钟不再响铃',
                  subtitleOnEnabled: '所有任务闹钟会正常响铃',
                  subtitleOnDisabled: '已关闭：全部闹钟已取消，重启后也不会响',
                ),
                AppSwitchTile(
                  icon: Icons.snooze_outlined,
                  title: '贪睡模式',
                  value: settings.snoozeEnabled,
                  onChanged: (v) =>
                      _setSnoozeEnabled(v, settings.snoozeMinutes),
                  subtitle: '响铃后可以「稍后提醒」，避免被一次闹钟打断',
                  subtitleOnEnabled: '响铃后可延后 ${settings.snoozeMinutes} 分钟再次提醒',
                  subtitleOnDisabled: '响铃后只能直接关闭，不能延后提醒',
                ),
                if (settings.snoozeEnabled)
                  _ChoiceTile<int>(
                    icon: Icons.timer_outlined,
                    title: '贪睡间隔',
                    subtitle: '「稍后提醒」的等待时长',
                    value: settings.snoozeMinutes,
                    options: const {5: '5 分钟', 10: '10 分钟', 15: '15 分钟'},
                    onChanged: (value) async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .patch(snoozeMinutes: value);
                      _toast('贪睡间隔已设为 $value 分钟');
                    },
                  )
                else
                  // 依赖未满足 → 合规的禁用（灰化 + 写明原因），不是假控件。
                  _LockedTile(
                    icon: Icons.timer_outlined,
                    title: '贪睡间隔',
                    reason: '需先开启贪睡模式',
                    valueLabel: '${settings.snoozeMinutes} 分钟',
                  ),
                // 铃音没有下游消费者（原生 AlarmService 只读 volume，raw/ 里只有 1 首
                // alarm_gentle.wav），做成 Dropdown 就是「点了没效果」的假控件 → 灰化。
                const AppDisabledTile(
                  icon: Icons.music_note_outlined,
                  title: '闹钟铃音',
                  reason: 'V1 只内置 1 首铃音（风铃轻响）；音色选择随铃音包开放',
                ),
                _VolumeRow(
                  value: volume,
                  onChanged: (v) => setState(() => _volumeDraft = v),
                  onChangeEnd: (v) async {
                    await ref
                        .read(appSettingsProvider.notifier)
                        .patch(volume: v);
                    if (!mounted) return;
                    setState(() => _volumeDraft = null);
                    _toast('闹钟音量已设为 $v%');
                  },
                ),
              ],
            ),

            const AppSectionHeader('数据与备份', subtitle: '把任务 / 日记 / 闹钟打包带走'),

            // ---------------- 数据与备份 ----------------
            AppCard.group(
              children: [
                if (_exporting)
                  const AppSettingsTile(
                    icon: Icons.archive_outlined,
                    title: '正在导出…',
                    subtitle: '正在合并 WAL 并打包数据库与设置',
                    trailing: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  AppActionTile(
                    icon: Icons.archive_outlined,
                    title: '导出全部数据（ZIP）',
                    subtitle: '数据库 + 设置打包，可分享到其他设备',
                    onTap: _exportData,
                  ),
                if (_restoring)
                  const AppSettingsTile(
                    icon: Icons.settings_backup_restore,
                    title: '正在恢复…',
                    subtitle: '正在校验备份、替换数据库并重新打开',
                    trailing: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  AppActionTile(
                    icon: Icons.settings_backup_restore,
                    title: '从备份恢复（ZIP）',
                    subtitle: '选择导出的备份包，覆盖当前数据（会先另存一份现有库）',
                    onTap: _restoreData,
                  ),
                // 自动备份：开关 + 上次备份时间就在这一行，不另开页面
                AppSwitchTile(
                  icon: Icons.autorenew_rounded,
                  title: '自动备份',
                  value: settings.autoBackupEnabled,
                  onChanged: _toggleAutoBackup,
                  subtitle: '每 7 天自动导出一次，只保留最近 4 份',
                  subtitleOnEnabled:
                      '每 7 天自动备份 · '
                      '${autoBackupStatusLabel(lastAutoBackupAt, DateTime.now())}',
                  subtitleOnDisabled: '已关闭：不会再自动备份（手动导出与恢复不受影响）',
                ),
              ],
            ),

            const AppSectionHeader('桌面', subtitle: '把今天的任务放到桌面上'),

            // ---------------- 桌面小组件 ----------------
            AppCard.group(
              children: [
                AppActionTile(
                  icon: Icons.widgets_outlined,
                  title: '添加「今日任务」到桌面',
                  subtitle: '4×2 卡片：日期 + 已完成 X / Y + 前 3 条未完成，点击打开应用',
                  onTap: _addWidgetToHome,
                ),
              ],
            ),

            const AppSectionHeader('关于'),

            // ---------------- 关于 ----------------
            AppCard.group(
              children: const [
                AppSettingsTile(
                  icon: Icons.info_outline,
                  // kAppVersion 是 const 常量，插值后仍是编译期常量
                  title: '版本 $kAppVersion',
                  subtitle: '专注任务 / 日记 / 工具箱的极简效率工具',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
    ThemeMode.system => '跟随系统',
  };

  static String _repeatLabel(String rule) => switch (rule) {
    'once' => '单次',
    'weekly' => '每周',
    _ => '每日',
  };

  /// 把存进来的值收敛到三个合法字面量之一（与新建任务页的解析规则一致）。
  static String _validRepeat(String rule) => switch (rule) {
    'once' => 'once',
    'weekly' => 'weekly',
    _ => 'daily',
  };
}

/// 当前闹钟档位（评审点名的那一行「有 API 没 UI」）。
///
/// 三态都由 [AsyncValue] 直接映射：加载 → 进度、报错 → 可重试的错误提示、
/// 成功 → 绿/橙两档（D4），未授权时给「去开启」（D5）。
class _ExactAlarmTile extends StatelessWidget {
  const _ExactAlarmTile({
    required this.asyncStatus,
    required this.onRequestPermission,
    required this.onRetry,
  });

  final AsyncValue<bool> asyncStatus;
  final VoidCallback onRequestPermission;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return asyncStatus.when(
      loading: () => const AppSettingsTile(
        icon: Icons.alarm,
        title: '当前闹钟档位',
        subtitle: '正在读取系统「闹钟和提醒」权限…',
        trailing: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => AppStatusTile(
        icon: Icons.alarm,
        title: '当前闹钟档位：未知',
        subtitle: '读取系统权限失败（原生通道不可用），请下拉刷新重试',
        ok: false,
        trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
      ),
      data: (exact) => AppStatusTile(
        icon: Icons.alarm,
        title: exact ? '当前闹钟档位：精确' : '当前闹钟档位：近似',
        subtitle: exact ? '精确档 · 闹钟将准时响铃' : '近似档 · 系统可能延迟几分钟响铃',
        ok: exact,
        trailing: exact
            ? null
            : TextButton(
                onPressed: onRequestPermission,
                child: const Text('去开启'),
              ),
      ),
    );
  }
}

/// 主题选择行：文字行 + 独占一行的分段按钮。
/// 为什么分段按钮不塞进 `trailing`：三个中文段标签 + 图标在窄屏会溢出。
class _ThemeModeRow extends StatelessWidget {
  const _ThemeModeRow({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static const Map<ThemeMode, String> _labels = {
    ThemeMode.system: '系统',
    ThemeMode.light: '浅色',
    ThemeMode.dark: '深色',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSettingsTile(
          icon: Icons.palette_outlined,
          title: '外观 · 主题',
          subtitle: '当前：${_labels[mode]} · 选择后立即生效并记住',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding + AppDimens.leadingIconWidth,
            0,
            AppDimens.pagePadding,
            AppDimens.cardPadding * 2,
          ),
          child: FittedBox(
            // 窄屏 / 大字号时按比例缩小，避免三个分段挤出 RenderFlex overflow。
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('系统'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('浅色'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('深色'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
          ),
        ),
      ],
    );
  }
}

/// 下拉选择行：`AppSettingsTile` + 右侧 DropdownButton。
///
/// `options` 是「值 → 展示文案」的映射，顺带解决了「存进来的值不在候选项里」
/// （比如手工改过 json）时 DropdownButton 的断言崩溃：自动退回第一项展示。
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = options.containsKey(value) ? value : options.keys.first;
    return AppSettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: DropdownButton<T>(
        value: current,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: [
          for (final entry in options.entries)
            DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (next) {
          if (next == null || next == current) return;
          onChanged(next);
        },
      ),
    );
  }
}

/// 音量行：滑块 + 右侧百分比。拖动只改本地草稿，`onChangeEnd` 才落库。
class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSettingsTile(
          icon: Icons.volume_up_outlined,
          title: '闹钟音量',
          subtitle: '拖动滑块调整响铃音量，松手后自动保存',
          trailing: Text(
            '$value%',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding + AppDimens.leadingIconWidth,
            0,
            AppDimens.pagePadding,
            AppDimens.cardPadding,
          ),
          child: Slider(
            value: value.toDouble(),
            max: 100,
            divisions: 100,
            label: '$value%',
            onChanged: (v) => onChanged(v.round()),
            onChangeEnd: (v) => onChangeEnd(v.round()),
          ),
        ),
      ],
    );
  }
}

/// 依赖未满足的行：`ListTile(enabled: false)` 会自动把图标与文字涂成
/// `Theme.disabledColor`（D4 的「灰 + 明确原因」），并且**不可点击**。
class _LockedTile extends StatelessWidget {
  const _LockedTile({
    required this.icon,
    required this.title,
    required this.reason,
    this.valueLabel,
  });

  final IconData icon;
  final String title;
  final String reason;

  /// 被禁用的那个值本身（如当前贪睡间隔），灰着也要让用户看见。
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      enabled: false,
      leading: SizedBox(
        width: AppDimens.leadingIconWidth,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(icon, size: 18),
        ),
      ),
      title: Text(title),
      subtitle: Text(reason),
      trailing: valueLabel == null
          ? null
          : Text(valueLabel!, style: TextStyle(color: theme.disabledColor)),
    );
  }
}

/// 确认弹窗里的一行「标签 · 值」。
///
/// 单独写而不是用 `ListTile`：弹窗里横向空间很窄，ListTile 的 16dp 内边距
/// 会把「备份版本」这种长值挤成两行，看起来像个没对齐的表。
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 恢复中的遮罩：**不可取消**（此时数据库正在被关闭/替换，取消只会留下半成品）。
class _RestoreProgressDialog extends StatelessWidget {
  const _RestoreProgressDialog();

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('正在恢复数据，请勿退出应用…')),
          ],
        ),
      ),
    );
  }
}
