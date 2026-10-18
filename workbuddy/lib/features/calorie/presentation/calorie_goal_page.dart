import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/calorie.dart';

/// 目标设置：Mifflin-St Jeor + 活动系数。
///
/// 为什么把「公式参数」也存下来：只存一个目标数字，用户下次想微调（比如体重变了）
/// 就得重新填一遍；存参数才能一键重算。
class CalorieGoalPage extends ConsumerStatefulWidget {
  const CalorieGoalPage({super.key});

  @override
  ConsumerState<CalorieGoalPage> createState() => _CalorieGoalPageState();
}

class _CalorieGoalPageState extends ConsumerState<CalorieGoalPage> {
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late CalorieSex _sex;
  late double _activity;
  int? _preview;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _age = TextEditingController(text: '${s.calorieAge}');
    _height = TextEditingController(text: '${s.calorieHeightCm}');
    _weight = TextEditingController(text: '${s.calorieWeightKg}');
    _sex = CalorieSex.byId(s.calorieSex);
    _activity = s.calorieActivity;
    _recalc();
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _recalc() {
    _preview = targetCalories(
      sex: _sex,
      weightKg: double.tryParse(_weight.text.trim()) ?? 0,
      heightCm: double.tryParse(_height.text.trim()) ?? 0,
      age: int.tryParse(_age.text.trim()) ?? 0,
      activityFactor: _activity,
    );
  }

  Future<void> _save() async {
    _recalc();
    final target = _preview;
    if (target == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('年龄/身高/体重都要填正数')));
      return;
    }
    await ref
        .read(appSettingsProvider.notifier)
        .patch(
          calorieTarget: target,
          calorieSex: _sex.id,
          calorieAge: int.tryParse(_age.text.trim()),
          calorieHeightCm: int.tryParse(_height.text.trim()),
          calorieWeightKg: int.tryParse(_weight.text.trim()),
          calorieActivity: _activity,
        );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('目标已更新：$target kcal / 天')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('目标设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
        children: [
          const AppSectionHeader('当前目标'),
          AppCard(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Row(
              children: [
                Icon(Icons.flag, color: theme.colorScheme.primary),
                const SizedBox(width: AppDimens.cardGap),
                Text(
                  '${settings.calorieTarget} kcal / 天',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const AppSectionHeader(
            '按身体数据重算',
            subtitle: 'Mifflin-St Jeor 公式 × 活动系数',
          ),
          AppCard(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<CalorieSex>(
                  segments: const [
                    ButtonSegment(
                      value: CalorieSex.male,
                      label: Text('男'),
                      icon: Icon(Icons.male),
                    ),
                    ButtonSegment(
                      value: CalorieSex.female,
                      label: Text('女'),
                      icon: Icon(Icons.female),
                    ),
                  ],
                  selected: {_sex},
                  onSelectionChanged: (v) => setState(() {
                    _sex = v.first;
                    _recalc();
                  }),
                ),
                const SizedBox(height: AppDimens.cardGap),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        controller: _age,
                        label: '年龄',
                        suffix: '岁',
                        onChanged: () => setState(_recalc),
                      ),
                    ),
                    const SizedBox(width: AppDimens.cardGap),
                    Expanded(
                      child: _NumberField(
                        controller: _height,
                        label: '身高',
                        suffix: 'cm',
                        onChanged: () => setState(_recalc),
                      ),
                    ),
                    const SizedBox(width: AppDimens.cardGap),
                    Expanded(
                      child: _NumberField(
                        controller: _weight,
                        label: '体重',
                        suffix: 'kg',
                        onChanged: () => setState(_recalc),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.cardGap),
                DropdownButtonFormField<double>(
                  initialValue: _activity,
                  decoration: const InputDecoration(
                    labelText: '活动水平',
                    prefixIcon: Icon(Icons.directions_run),
                  ),
                  items: [
                    for (final level in kActivityLevels)
                      DropdownMenuItem(
                        value: level.factor,
                        child: Text(
                          '${level.label}（×${level.factor}）',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _activity = v ?? _activity;
                    _recalc();
                  }),
                ),
                const SizedBox(height: AppDimens.chipGap),
                Text(
                  kActivityLevels
                      .firstWhere(
                        (l) => l.factor == _activity,
                        orElse: () => kActivityLevels.first,
                      )
                      .description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const AppSectionHeader('算出来'),
          AppCard(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _preview == null ? '—' : '$_preview kcal / 天',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: _preview == null
                        ? AppColors.warning
                        : AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimens.chipGap),
                Text(
                  '男：10×体重 + 6.25×身高 − 5×年龄 + 5；女：末项 −161；再乘活动系数。'
                  '只是估算值，减脂/增肌请按 200–300 kcal 的幅度调整。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
              onPressed: _preview == null ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('保存为目标'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
      ),
    );
  }
}
