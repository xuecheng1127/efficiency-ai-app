import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/notifications/app_notifications.dart';
import '../../../core/widgets/ui_kit.dart';
import '../application/birthday_reminders.dart';
import '../domain/birthday.dart';
import '../providers/birthday_providers.dart';

/// 新增 / 编辑生日。
///
/// 交互取舍：
/// - 月/日 用下拉而不是日期选择器 —— 生日要的是「月+日」，年份可选，
///   `showDatePicker` 会强迫用户先选一个具体年份，反而多一步。
/// - 农历同样用「月/日」两个下拉，换算交给 `lunar` 包在保存后计算。
class BirthdayEditPage extends ConsumerStatefulWidget {
  const BirthdayEditPage({super.key, this.existing});

  /// 非空 = 编辑
  final Birthday? existing;

  @override
  ConsumerState<BirthdayEditPage> createState() => _BirthdayEditPageState();
}

class _BirthdayEditPageState extends ConsumerState<BirthdayEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _year;
  late final TextEditingController _group;
  late final TextEditingController _notes;

  late BirthdayCalendar _calendar;
  late int _month;
  late int _day;
  late int _advanceDays;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  static const List<int> _advanceOptions = [0, 1, 3, 7, 14];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _year = TextEditingController(
      text: (e?.birthdayYear ?? 0) > 0 ? '${e!.birthdayYear}' : '',
    );
    _group = TextEditingController(text: e?.groupTag ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _calendar = e?.calendar ?? BirthdayCalendar.solar;
    _month = e?.month ?? 1;
    _day = e?.day ?? 1;
    _advanceDays = e?.advanceDays ?? 3;
  }

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _group.dispose();
    _notes.dispose();
    super.dispose();
  }

  int get _maxDay {
    if (_calendar == BirthdayCalendar.lunar) return 30;
    // 公历按最宽的 31 天给候选（2 月 29 之类的非法组合不会崩：保存时按 2 月 28 处理）
    return DateTime(2024, _month + 1, 0).day;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '先写个名字吧（不然不知道是谁的生日）');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(birthdayRepositoryProvider);
    final year = int.tryParse(_year.text.trim());
    try {
      int id;
      if (_isEdit) {
        id = widget.existing!.id;
        await repo.update(
          id,
          name: name,
          month: _month,
          day: _day,
          calendar: _calendar,
          year: year,
          clearYear: year == null,
          groupTag: _group.text,
          clearGroupTag: _group.text.trim().isEmpty,
          advanceDays: _advanceDays,
          notes: _notes.text,
          clearNotes: _notes.text.trim().isEmpty,
        );
      } else {
        final created = await repo.create(
          name: name,
          month: _month,
          day: _day,
          calendar: _calendar,
          year: year,
          groupTag: _group.text,
          advanceDays: _advanceDays,
          notes: _notes.text,
        );
        if (created == null) {
          setState(() {
            _saving = false;
            _error = '保存失败，请重试';
          });
          return;
        }
        id = created;
      }

      // 排提醒：先取消旧的再按最新配置排（改了提前天数 / 改了月日都要重排）
      // 顺便在这里申请通知权限 —— 用户此刻正在创建提醒，语境最自然。
      await AppNotifications.ensurePermission();
      final saved = await repo.findById(id);
      if (saved != null) await BirthdayReminders.syncOne(saved);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? '已更新「$name」' : '已添加「$name」')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑生日' : '添加生日')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
        children: [
          const AppSectionHeader('是谁的生日'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.pagePadding,
              vertical: AppDimens.cardPadding,
            ),
            child: TextField(
              controller: _name,
              autofocus: !_isEdit,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                border: InputBorder.none,
                icon: Icon(Icons.person_outline),
                hintText: '名字（必填）',
              ),
            ),
          ),
          const AppSectionHeader('哪天'),
          AppCard(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<BirthdayCalendar>(
                  segments: const [
                    ButtonSegment(
                      value: BirthdayCalendar.solar,
                      label: Text('公历'),
                      icon: Icon(Icons.calendar_today_outlined),
                    ),
                    ButtonSegment(
                      value: BirthdayCalendar.lunar,
                      label: Text('农历'),
                      icon: Icon(Icons.nightlight_outlined),
                    ),
                  ],
                  selected: {_calendar},
                  onSelectionChanged: (v) => setState(() {
                    _calendar = v.first;
                    // 切成农历后 31 日不存在，收敛到 30
                    if (_day > _maxDay) _day = _maxDay;
                  }),
                ),
                const SizedBox(height: AppDimens.cardGap),
                Row(
                  children: [
                    Expanded(
                      child: _NumberDropdown(
                        label: '月',
                        value: _month,
                        items: List.generate(12, (i) => i + 1),
                        display: (v) => _calendar == BirthdayCalendar.lunar
                            ? '${_lunarMonthName(v)}月'
                            : '$v 月',
                        onChanged: (v) => setState(() {
                          _month = v;
                          if (_day > _maxDay) _day = _maxDay;
                        }),
                      ),
                    ),
                    const SizedBox(width: AppDimens.cardGap),
                    Expanded(
                      child: _NumberDropdown(
                        label: '日',
                        value: _day,
                        items: List.generate(_maxDay, (i) => i + 1),
                        display: (v) => '$v 日',
                        onChanged: (v) => setState(() => _day = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.cardGap),
                TextField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: '出生年份（可留空）',
                    helperText: _calendar == BirthdayCalendar.lunar
                        ? '农历年份也填公历年即可，只用于显示年龄'
                        : '只用于算年龄，不影响提醒',
                  ),
                ),
              ],
            ),
          ),
          const AppSectionHeader('提醒与分组'),
          AppCard(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _advanceDays,
                  decoration: const InputDecoration(
                    labelText: '提前几天提醒',
                    prefixIcon: Icon(Icons.notifications_active_outlined),
                  ),
                  items: [
                    for (final d in _advanceOptions)
                      DropdownMenuItem(
                        value: d,
                        child: Text(d == 0 ? '当天 09:00' : '提前 $d 天 09:00'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _advanceDays = v ?? 3),
                ),
                const SizedBox(height: AppDimens.cardGap),
                TextField(
                  controller: _group,
                  decoration: const InputDecoration(
                    labelText: '分组（可留空）',
                    hintText: '家人 / 朋友 / 同事',
                    prefixIcon: Icon(Icons.group_outlined),
                  ),
                ),
                const SizedBox(height: AppDimens.cardGap),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注（可留空）',
                    hintText: '想送的礼物、忌口、上次聊到的事…',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.cardGap,
                AppDimens.pagePadding,
                0,
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
                  const SizedBox(width: AppDimens.chipGap),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.sectionGap,
              AppDimens.pagePadding,
              0,
            ),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? '保存中…' : '保存'),
            ),
          ),
        ],
      ),
    );
  }

  static String _lunarMonthName(int month) {
    const names = [
      '正',
      '二',
      '三',
      '四',
      '五',
      '六',
      '七',
      '八',
      '九',
      '十',
      '冬',
      '腊',
    ];
    return names[(month - 1).clamp(0, 11)];
  }
}

class _NumberDropdown extends StatelessWidget {
  const _NumberDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> items;
  final String Function(int) display;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final v in items)
          DropdownMenuItem(value: v, child: Text(display(v))),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}
