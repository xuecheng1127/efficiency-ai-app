import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/task_enums.dart';
import '../providers/task_providers.dart';

/// 新建任务页（独立页面，替代原来的新建对话框）。
///
/// **返回值约定**（调用方用 `Navigator.push<bool>` 打开）：
/// - 创建成功 → `Navigator.pop(context, true)`
/// - 取消 / 关闭 / 系统返回 → `Navigator.pop(context, false)`
class AddTaskPage extends ConsumerStatefulWidget {
  const AddTaskPage({super.key});

  @override
  ConsumerState<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends ConsumerState<AddTaskPage> {
  final TextEditingController _titleController = TextEditingController();

  /// 每周固定日：1=周一 … 7=周日，与 Dart `DateTime.weekday` 语义一致。
  final Set<int> _selectedWeekdays = <int>{};

  static const List<String> _weekdayLabels = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  TaskType _type = TaskType.study;
  RepeatMode _repeatMode = RepeatMode.daily;

  bool _submitting = false;
  bool _submitAttempted = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // 默认重复规则来自设置页（`AppSettings.defaultRepeatMode`）
    _repeatMode = _parseRepeatMode(
      ref.read(appSettingsProvider).defaultRepeatMode,
    );
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  static RepeatMode _parseRepeatMode(String raw) {
    switch (raw) {
      case 'once':
        return RepeatMode.once;
      case 'weekly':
        return RepeatMode.weekly;
      case 'daily':
      default:
        return RepeatMode.daily;
    }
  }

  String get _title => _titleController.text.trim();

  bool get _canSubmit {
    if (_submitting) return false;
    if (_title.isEmpty) return false;
    if (_repeatMode == RepeatMode.weekly && _selectedWeekdays.isEmpty) {
      return false;
    }
    return true;
  }

  String? get _titleError =>
      _submitAttempted && _title.isEmpty ? '请输入任务名称' : null;

  /// 按钮不可点时，明确告诉用户还缺什么（R1 的「灰化 + 写明原因」）。
  String get _disabledReason {
    if (_title.isEmpty) return '填写任务名称后可创建';
    if (_repeatMode == RepeatMode.weekly && _selectedWeekdays.isEmpty) {
      return '请至少选择一个重复日';
    }
    return '';
  }

  Future<void> _submit() async {
    final title = _title;
    if (title.isEmpty) {
      setState(() => _submitAttempted = true);
      return;
    }
    if (_repeatMode == RepeatMode.weekly && _selectedWeekdays.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final repo = ref.read(taskRepositoryProvider);
      await repo.addTemplate(
        type: _type,
        title: title,
        repeatMode: _repeatMode,
        repeatDays: _repeatMode == RepeatMode.weekly
            ? (_selectedWeekdays.toList()..sort())
            : const <int>[],
      );
      // 新增模板后立即补齐今日实例，保证任务列表马上能看到
      await repo.backfill(DateTime.now());

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已创建')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = '创建失败：$e';
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('创建失败：$e'), backgroundColor: AppColors.danger),
        );
    }
  }

  void _toggleWeekday(int weekday, bool selected) {
    setState(() {
      if (selected) {
        _selectedWeekdays.add(weekday);
      } else {
        _selectedWeekdays.remove(weekday);
      }
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope<bool>(
      // 系统返回也走「取消」分支，保证调用方拿到的结果始终是 true / false
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _submitting) return;
        Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('新建任务'),
          leading: IconButton(
            tooltip: _submitting ? '正在创建…' : '取消',
            icon: const Icon(Icons.close),
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(false),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
                  children: [
                    const AppSectionHeader(
                      '任务类型',
                      subtitle: '学习与健身共用同一套计时与提醒能力',
                    ),
                    AppCard(
                      padding: const EdgeInsets.all(AppDimens.pagePadding),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SegmentedButton<TaskType>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<TaskType>(
                              value: TaskType.study,
                              label: Text('学习'),
                              icon: Icon(Icons.menu_book_outlined),
                            ),
                            ButtonSegment<TaskType>(
                              value: TaskType.fitness,
                              label: Text('健身'),
                              icon: Icon(Icons.fitness_center),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (selection) =>
                              setState(() => _type = selection.first),
                        ),
                      ),
                    ),
                    const AppSectionHeader('任务名称', subtitle: '创建后立刻出现在「今日任务」里'),
                    AppCard(
                      padding: const EdgeInsets.all(AppDimens.pagePadding),
                      child: TextField(
                        controller: _titleController,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        maxLength: 40,
                        decoration: InputDecoration(
                          labelText: '任务标题',
                          hintText: '例如：背 50 个单词 / 跑步 20 分钟',
                          prefixIcon: const Icon(Icons.edit_outlined),
                          errorText: _titleError,
                        ),
                        onSubmitted: (_) async {
                          if (_canSubmit) await _submit();
                        },
                      ),
                    ),
                    const AppSectionHeader(
                      '重复规则',
                      subtitle: '默认值来自设置页「新任务默认重复规则」',
                    ),
                    AppCard(
                      padding: const EdgeInsets.all(AppDimens.pagePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SegmentedButton<RepeatMode>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment<RepeatMode>(
                                  value: RepeatMode.once,
                                  label: Text('单次'),
                                  icon: Icon(Icons.event_available_outlined),
                                ),
                                ButtonSegment<RepeatMode>(
                                  value: RepeatMode.daily,
                                  label: Text('每日'),
                                  icon: Icon(Icons.today_outlined),
                                ),
                                ButtonSegment<RepeatMode>(
                                  value: RepeatMode.weekly,
                                  label: Text('每周'),
                                  icon: Icon(Icons.date_range_outlined),
                                ),
                              ],
                              selected: {_repeatMode},
                              onSelectionChanged: (selection) => setState(() {
                                _repeatMode = selection.first;
                                _errorText = null;
                              }),
                            ),
                          ),
                          if (_repeatMode == RepeatMode.weekly) ...[
                            const SizedBox(height: AppDimens.cardGap),
                            Row(
                              children: [
                                Icon(
                                  Icons.event_repeat_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(
                                  width: AppDimens.sectionHeaderGap,
                                ),
                                Expanded(
                                  child: Text(
                                    '每周固定日（周一=1 … 周日=7），至少选 1 天',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimens.sectionHeaderGap),
                            Wrap(
                              // 7 个 chip 在 360dp 下必然换行；间距比区块间距小一档，
                              // 让换行落成 4+3，而不是 5+2（5+2 右半空、像漏排）
                              spacing: AppDimens.chipGap,
                              runSpacing: AppDimens.chipGap,
                              children: [
                                for (var weekday = 1; weekday <= 7; weekday++)
                                  FilterChip(
                                    label: Text(
                                      '周${_weekdayLabels[weekday - 1]}',
                                    ),
                                    selected: _selectedWeekdays.contains(
                                      weekday,
                                    ),
                                    onSelected: (selected) =>
                                        _toggleWeekday(weekday, selected),
                                  ),
                              ],
                            ),
                            if (_selectedWeekdays.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppDimens.sectionHeaderGap,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 16,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(
                                      width: AppDimens.sectionHeaderGap / 2,
                                    ),
                                    Expanded(
                                      child: Text(
                                        '至少选择 1 天，否则无法创建',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppColors.warning,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomBar(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 高频操作下沉：创建按钮固定在屏幕底部（键盘弹出时也保持在内容之上）。
  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.pagePadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_errorText != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppDimens.sectionHeaderGap / 2),
                Expanded(
                  child: Text(
                    _errorText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.sectionHeaderGap),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: _submitting
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: AppDimens.sectionHeaderGap),
                        const Text('创建中…'),
                      ],
                    )
                  : const Text('创建任务'),
            ),
          ),
          if (!_canSubmit && !_submitting) ...[
            const SizedBox(height: AppDimens.sectionHeaderGap / 2),
            Text(
              _disabledReason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
