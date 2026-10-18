import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/alarm_channel.dart';
import '../../../core/settings/app_settings.dart';
import '../domain/scheduled_alarm.dart';
import '../providers/alarm_providers.dart';

/// 内置铃音（PRD 要求 3–5 首轻柔纯音乐；本阶段只有 id，实际播放属 T14）
const List<({String id, String label})> kBuiltinRingtones = [
  (id: 'default', label: '轻柔钢琴（默认）'),
  (id: 'gentle_bell', label: '风铃轻响'),
  (id: 'soft_wind', label: '林间微风'),
];

/// 贪睡间隔候选（分钟）
const List<int> kSnoozeMinuteOptions = [5, 10, 15, 20];

/// 最小时钟设置对话框（T10）。
///
/// 存在的唯一理由：T10 的验收要求「**调度闹钟时**同步写入」，因此调度动作必须能被
/// 真实触发；对话框把 T10 要求的 11 个字段全部暴露出来，保存即走
/// `AlarmRepository.scheduleForTask`（先落盘，再交给原生）。
/// 它是 T10 的最小必要入口，不含贪睡/铃声实际播放等 T14 内容。
class AlarmEditorDialog extends ConsumerStatefulWidget {
  const AlarmEditorDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.defaultRepeatRule,
    this.existing,
  });

  final int taskId;
  final String taskTitle;

  /// 新闹钟的默认重复规则（沿用任务自身的重复模式）
  final String defaultRepeatRule;

  /// 已有闹钟（编辑态）；null 表示新建
  final ScheduledAlarm? existing;

  @override
  ConsumerState<AlarmEditorDialog> createState() => _AlarmEditorDialogState();
}

class _AlarmEditorDialogState extends ConsumerState<AlarmEditorDialog> {
  late int _hour;
  late int _minute;
  late String _repeatRule;
  late Set<int> _weekdays;
  int? _advanceMinutes;
  late String _ringtone;
  late double _volume;
  late bool _snoozeEnabled;
  late int _snoozeMinutes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    // UI 打磨：新建闹钟的「音量 / 贪睡」默认值来自全局设置（设置页真联动的落点）。
    // 只取这两个 —— `ringtone` 原生侧根本没人读（AlarmService 只读 volume），
    // 所以设置页的铃音项被改成禁用行，这里也不去消费它。
    final settings = ref.read(appSettingsProvider);
    _hour = e?.hour ?? 7;
    _minute = e?.minute ?? 0;
    _repeatRule = e?.repeatRule ?? widget.defaultRepeatRule;
    _weekdays = {...(e?.weekdays ?? const <int>[])};
    _advanceMinutes = e?.advanceMinutes;
    // 铃音**不**从设置里取：设置页存的 '风铃轻响' 是展示用的中文名，
    // 而本对话框的候选集是 id（default/gentle_bell/soft_wind）。
    // 取中文名会落进 DropdownButton 的 assert（value 必须在 items 里）→ debug 直接红屏。
    // 而且原生 `AlarmService` 根本不读这个字段，所以这里固定 'default'（只作为落库值）。
    _ringtone = e?.ringtone ?? 'default';
    _volume = (e?.volume ?? settings.volume).toDouble();
    _snoozeEnabled = e?.snoozeEnabled ?? settings.snoozeEnabled;
    _snoozeMinutes = e?.snoozeMinutes ?? settings.snoozeMinutes;
  }

  String get _timeLabel =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(alarmRepositoryProvider);
    // 总开关状态先取：await 之后 State 可能已 dispose，那时再读 ref 会抛。
    final remindersOn = ref.read(appSettingsProvider).remindersEnabled;
    final saved = await repo.scheduleForTask(
      taskId: widget.taskId,
      hour: _hour,
      minute: _minute,
      repeatRule: _repeatRule,
      weekdays: _repeatRule == 'weekly'
          ? (_weekdays.toList()..sort())
          : const [],
      advanceMinutes: _advanceMinutes,
      ringtone: _ringtone,
      volume: _volume.round(),
      snoozeEnabled: _snoozeEnabled,
      snoozeMinutes: _snoozeMinutes,
    );
    // UI 打磨（审查者发现的漏洞）：总开关关闭期间新建的闹钟不能"复活"。
    // `scheduleForTask` 插入的新行默认 enabled=true 且已交给原生调度，
    // 所以这里必须补一刀：把该行打回 0 + 撤掉刚排上的系统闹钟。
    // 否则用户关了总开关、再设一个闹钟，它会立刻生效并在重启后依然存在。
    if (!remindersOn) {
      await repo.setAllEnabled(false);
      try {
        await AlarmScheduler.cancel(widget.taskId);
      } catch (_) {
        // 原生取消失败不影响正确性：表里已是 enabled=0，开机重建不会把它带回来
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          remindersOn
              ? '闹钟已保存：${_repeatLabel(saved.repeatRule)} ${saved.timeLabel}'
                    '（已写入 scheduled_alarms）'
              : '闹钟已保存，但「任务提醒总开关」已关闭 → 此闹钟不会响'
                    '（去设置页打开总开关即可生效）',
        ),
      ),
    );

    // 场景化权限引导（PRD 全局交互规范「权限申请原则」）：
    // 只在**真的用到闹钟时**才申请，说明「用途 + 用户收益」，并给「暂不」；
    // 拒绝也不影响使用 —— 原生侧会自动降级为 B 近似档。
    final exact = await AlarmScheduler.canScheduleExactAlarms();
    if (!mounted || exact) return;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('开启「闹钟和提醒」权限'),
        content: const Text(
          '用途：让闹钟在系统待机 / 省电时也能被准时唤醒。\n'
          '收益：闹钟按点响，误差通常 1 分钟以内。\n'
          '不开也能用：会降级为「近似档」，到点时间可能有几分钟偏差。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('去开启'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await AlarmScheduler.requestExactAlarmPermission();
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    await ref.read(alarmRepositoryProvider).cancelForTask(widget.taskId);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已移除「${widget.taskTitle}」的闹钟')));
  }

  static String _repeatLabel(String rule) => switch (rule) {
    'once' => '单次',
    'weekly' => '每周',
    _ => '每日',
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('闹钟 · ${widget.taskTitle}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 提醒时刻
            Row(
              children: [
                const Text('提醒时刻'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(_timeLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 重复规则
            DropdownButtonFormField<String>(
              initialValue: _repeatRule,
              decoration: const InputDecoration(labelText: '重复'),
              items: const [
                DropdownMenuItem(value: 'once', child: Text('单次')),
                DropdownMenuItem(value: 'daily', child: Text('每日')),
                DropdownMenuItem(value: 'weekly', child: Text('每周固定日')),
              ],
              onChanged: (v) => setState(() => _repeatRule = v ?? 'daily'),
            ),
            if (_repeatRule == 'weekly') ...[
              const SizedBox(height: 8),
              const Text('星期'),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(
                        const ['一', '二', '三', '四', '五', '六', '日'][d - 1],
                      ),
                      selected: _weekdays.contains(d),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _weekdays.add(d);
                        } else {
                          _weekdays.remove(d);
                        }
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // 提前提醒（0 = 不提前；下拉不能用 null 值项，避免「选中不生效」的经典坑）
            DropdownButtonFormField<int>(
              initialValue: _advanceMinutes ?? 0,
              decoration: const InputDecoration(labelText: '提前提醒'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('不提前')),
                DropdownMenuItem(value: 15, child: Text('提前 15 分钟')),
                DropdownMenuItem(value: 30, child: Text('提前 30 分钟')),
              ],
              onChanged: (v) => setState(
                () => _advanceMinutes = (v == null || v == 0) ? null : v,
              ),
            ),
            const SizedBox(height: 8),
            // 铃音：原生 `AlarmService` **不读** ringtone 字段（只读 volume），
            // 且 res/raw 只有 1 首铃音。所以这里**不做可选控件**（R1：禁止"选了没效果"），
            // 只如实展示现状。
            const ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.music_note_outlined, size: 20),
              title: Text('铃音'),
              subtitle: Text('风铃轻响 · V1 只内置 1 首，音色选择随铃音包开放'),
            ),
            const SizedBox(height: 8),
            // 音量
            Text('音量 ${_volume.round()}%'),
            Slider(
              value: _volume,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_volume.round()}%',
              onChanged: (v) => setState(() => _volume = v),
            ),
            // 贪睡
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('贪睡'),
              value: _snoozeEnabled,
              onChanged: (v) => setState(() => _snoozeEnabled = v),
            ),
            if (_snoozeEnabled)
              DropdownButtonFormField<int>(
                initialValue: _snoozeMinutes,
                decoration: const InputDecoration(labelText: '贪睡间隔'),
                items: [
                  for (final m in kSnoozeMinuteOptions)
                    DropdownMenuItem(value: m, child: Text('$m 分钟')),
                ],
                onChanged: (v) => setState(() => _snoozeMinutes = v ?? 5),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: const Text('移除闹钟'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
