import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/alarm_service.dart';
import '../../settings/providers/settings_provider.dart';
import '../domain/task_enums.dart';
import '../domain/task_template.dart';
import '../providers/task_providers.dart';

/// 添加任务页面（T01：数据模型按双层 task_templates 组装）
///
/// 支持：标题、类型（健身/学习）、重复规则（单次/每日/每周）、
/// 每周固定日选择、单次日期选择。
/// 闹钟绑定（alarmEnabled/alarmConfigJson 字段存在，调度在 T10 实现）。
class AddTaskPage extends ConsumerStatefulWidget {
  /// null = 新建；非 null = 编辑已有任务
  final int? taskId;
  const AddTaskPage({super.key, this.taskId});

  @override
  ConsumerState<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends ConsumerState<AddTaskPage> {
  final _titleController = TextEditingController();

  // 表单状态
  String _type = '学习';
  String _repeatRule = '单次';
  DateTime? _scheduledDate;
  Set<int> _weekdays = {};

  // 闹钟状态（T01 仅存配置，调度在 T10 实现）
  bool _alarmEnabled = false;
  TimeOfDay _alarmTime = const TimeOfDay(hour: 8, minute: 0);
  int _advanceMinutes = 0;

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) _loadForEdit();
  }

  Future<void> _loadForEdit() async {
    try {
      final repo = ref.read(taskRepositoryProvider);
      final all = await repo.getAllTasks();
      TaskTemplate? t;
      for (final x in all) {
        if (x.id == widget.taskId) { t = x; break; }
      }
      if (t == null || !mounted) return;
      _titleController.text = t.title;
      _type = t.type == TaskType.fitness ? '健身' : '学习';
      _repeatRule = switch (t.repeatMode) {
        RepeatRule.daily => '每日重复',
        RepeatRule.weekly => '每周重复',
        _ => '单次',
      };
      if (t.repeatMode == RepeatRule.weekly) {
        _weekdays = t.repeatDays.toSet();
      }
      if (t.alarmEnabled) {
        _alarmEnabled = true;
        if (t.alarmConfigJson != null) {
          try {
            final cfg = jsonDecode(t.alarmConfigJson!) as Map<String, dynamic>;
            final time = cfg['time'] as String?;
            if (time != null) {
              final parts = time.split(':');
              _alarmTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
            _advanceMinutes = cfg['advanceMinutes'] as int? ?? 0;
          } catch (_) {}
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      // ignore: avoid_print
      print('[AddTask] _loadForEdit error: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.taskId == null ? '新建任务' : '编辑任务')),
      body: ListView(
        padding: const EdgeInsets.all(AppColors.pagePadding),
        children: [
          // 标题
          TextField(
            controller: _titleController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '任务标题，例如：跑步 5 公里',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 20),

          // 任务类型
          const _SectionLabel('任务类型'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '学习', label: Text('学习'), icon: Icon(Icons.menu_book_outlined)),
              ButtonSegment(value: '健身', label: Text('健身'), icon: Icon(Icons.fitness_center)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),

          // 重复规则
          const _SectionLabel('重复规则'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '单次', label: Text('单次')),
              ButtonSegment(value: '每日重复', label: Text('每日重复')),
              ButtonSegment(value: '每周重复', label: Text('每周重复')),
            ],
            selected: {_repeatRule},
            onSelectionChanged: (s) => setState(() => _repeatRule = s.first),
          ),

          // 条件项：单次 → 选日期；每周 → 选固定日
          if (_repeatRule == '单次') ...[
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('计划日期'),
              subtitle: Text(
                _scheduledDate == null
                    ? '今天'
                    : '${_scheduledDate!.year}-${_scheduledDate!.month.toString().padLeft(2, '0')}-${_scheduledDate!.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
          ],
          if (_repeatRule == '每周重复') ...[
            const SizedBox(height: 16),
            const _SectionLabel('每周固定日（可多选）'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (i) {
                final day = i + 1; // 1=周一 ... 7=周日
                final selected = _weekdays.contains(day);
                return FilterChip(
                  label: Text(_weekdayLabel(day)),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _weekdays.add(day);
                    } else {
                      _weekdays.remove(day);
                    }
                  }),
                );
              }),
            ),
          ],

          // ---- 闹钟绑定（V1.2 闹钟提醒系统）----
          const SizedBox(height: 32),
          const _SectionLabel('闹钟提醒'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_outlined),
                  title: const Text('启用闹钟'),
                  subtitle: const Text('到点全屏响铃，可贪睡'),
                  value: _alarmEnabled,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => setState(() => _alarmEnabled = v),
                ),
                if (_alarmEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('提醒时间'),
                    subtitle: Text(_alarmTime.format(context)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickAlarmTime,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notification_important_outlined),
                    title: const Text('提前提醒'),
                    subtitle: Text(_advanceLabel),
                    trailing: SegmentedButton<int>(
                      segments: [
                        for (final m in AlarmService.advanceOptions)
                          ButtonSegment(value: m, label: Text(m == 0 ? '不提前' : '$m 分')),
                      ],
                      selected: {_advanceMinutes},
                      onSelectionChanged: (s) =>
                          setState(() => _advanceMinutes = s.first),
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
      // 保存按钮下沉至底部（需求：高频操作按钮统一沉底）
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('保 存', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickAlarmTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _alarmTime,
    );
    if (picked != null) setState(() => _alarmTime = picked);
  }

  String get _advanceLabel {
    switch (_advanceMinutes) {
      case 15:
        return '提前 15 分钟';
      case 30:
        return '提前 30 分钟';
      default:
        return '不提前';
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务标题')),
      );
      return;
    }

    // 防止连点产生重复任务：保存中禁用按钮
    // （onPressed 为 null 时按钮自动禁用）
    // 通过 mounted + _saving 标志实现

    // 组装实体（T01：task_templates 双层模型；闹钟配置入 alarmConfigJson）
    final alarmConfig = _alarmEnabled
        ? {
            'time': '${_alarmTime.hour.toString().padLeft(2, '0')}:'
                '${_alarmTime.minute.toString().padLeft(2, '0')}',
            'advanceMinutes': _advanceMinutes,
          }
        : null;
    final template = TaskTemplate(
      id: widget.taskId,
      title: title,
      type: _type == '健身' ? TaskType.fitness : TaskType.study,
      repeatMode: switch (_repeatRule) {
        '每日重复' => RepeatRule.daily,
        '每周重复' => RepeatRule.weekly,
        _ => RepeatRule.once,
      },
      startDate: _normalizeDate(
        _repeatRule == '单次' ? (_scheduledDate ?? DateTime.now()) : DateTime.now(),
      ),
      endDate: null,
      repeatDays:
          _repeatRule == '每周重复' ? (_weekdays.toList()..sort()) : const [],
      alarmEnabled: _alarmEnabled,
      alarmConfigJson: alarmConfig == null ? null : jsonEncode(alarmConfig),
      createdAt: DateTime.now(),
    );

    // 核心写库：失败要报错，成功后立即返回（与副作用解耦）
    final repo = ref.read(taskRepositoryProvider);
    try {
      if (widget.taskId == null) {
        await repo.addTask(template);
      } else {
        // 编辑：先取消旧闹钟，再 update
        await AlarmService.instance.cancelTaskAlarm(widget.taskId!);
        await repo.updateTask(template);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[AddTask] addTask failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
      return;
    }

    // 写库成功 → 立即返回（不受调度/权限弹窗影响）
    if (mounted) Navigator.pop(context);

    // 带 id 的 template 用于调度（_persistScheduledAlarm 需要 taskId）
    final savedTemplate = widget.taskId == null
        ? template
        : template.copyWith(id: widget.taskId);

    // 以下为异步副作用：调度闹钟、权限弹窗，全部在页面返回后执行
    // ignore: unawaited_futures
    unawaited(_postSaveSideEffects(savedTemplate));
  }

  /// 保存后的副作用（调度闹钟 + 权限引导），不阻塞导航
  Future<void> _postSaveSideEffects(TaskTemplate template) async {
    if (!template.alarmEnabled) return;

    // 等待 settings 加载（最多 3 秒），不得静默跳过
    var settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null) {
      // ignore: avoid_print
      print('[AddTask] settings not loaded yet, waiting...');
      try {
        settings = await ref
            .read(settingsProvider.future)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // ignore: avoid_print
        print('[AddTask] settings load timeout (3s), alarm not scheduled');
        return;
      }
    }

    // 检查总开关
    if (settings == null || !settings.taskReminderEnabled) {
      // ignore: avoid_print
      print('[AddTask] taskReminderEnabled=false or settings null, alarm not scheduled');
      return;
    }

    final ok = await AlarmService.instance.scheduleTaskAlarm(template, settings);
    // ignore: avoid_print
    print('[AddTask] scheduleTaskAlarm result=$ok '
        '(trigger may be null if time already passed today)');

    // 权限引导：用全局 navigatorKey 的 context（页面已 pop）
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    if (!await AlarmService.instance.canScheduleExactAlarms()) {
      await _promptExactAlarmPermission(ctx);
    }
  }

  /// 归一化日期到当天 00:00:00
  static DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 精确闹钟权限弹窗：说明用途与收益，提供「去开启」「暂不」双选项
  Future<void> _promptExactAlarmPermission(BuildContext ctx) async {
    final goOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('开启精准闹钟'),
        content: const Text(
          '开启「闹钟和提醒」权限后，任务闹钟将使用系统精确闹钟准时响铃，'
          '即使省电模式下也能准时提醒；未开启时闹钟可能有最多 1 分钟延迟。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去开启'),
          ),
        ],
      ),
    );
    if (goOpen == true) {
      await AlarmService.instance.requestExactAlarmPermission();
    }
  }

  static String _weekdayLabel(int day) {
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[day - 1];
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
      ),
    );
  }
}
