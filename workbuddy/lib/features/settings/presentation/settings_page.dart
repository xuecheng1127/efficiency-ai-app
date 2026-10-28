import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/theme_provider.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/platform/alarm_channel.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../backup/application/export_backup.dart';
import '../../backup/providers/backup_providers.dart';
import '../providers/reminder_switch.dart';

/// ============================================================================
/// 设置页（重写版）
/// ============================================================================
///
/// 设计约束来自《UI 验收标准》：
/// - R1 禁止假控件：已实现的「导出全部数据」是真入口；未实现的「从备份恢复」
///   仍用 [AppDisabledTile] 灰化并写明原因；
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final volume = _volumeDraft ?? settings.volume;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
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
                const AppDisabledTile(
                  icon: Icons.settings_backup_restore,
                  title: '从备份恢复',
                  reason: '后续迭代开放：选择 ZIP 覆盖当前数据',
                ),
              ],
            ),

            const AppSectionHeader('关于'),

            // ---------------- 关于 ----------------
            AppCard.group(
              children: const [
                AppSettingsTile(
                  icon: Icons.info_outline,
                  title: '版本 1.0.0',
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
