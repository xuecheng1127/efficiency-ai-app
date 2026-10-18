import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calorie_repository.dart';
import '../providers/calorie_providers.dart';

class CalorieTargetPage extends ConsumerStatefulWidget {
  const CalorieTargetPage({super.key});

  @override
  ConsumerState<CalorieTargetPage> createState() => _CalorieTargetPageState();
}

class _CalorieTargetPageState extends ConsumerState<CalorieTargetPage> {
  String _gender = 'male';
  double _activity = 1.375;
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _age = TextEditingController();
  final _target = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await ref.read(calorieRepoProvider).getTarget();
    if (mounted) _target.text = '$t';
  }

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    _age.dispose();
    _target.dispose();
    super.dispose();
  }

  Widget _activityChip(String label, double value) {
    final selected = _activity == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _activity = value),
    );
  }

  @override
  Widget build(BuildContext context) {    return Scaffold(
      appBar: AppBar(title: const Text('热量目标')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'male', label: Text('男')),
              ButtonSegment(value: 'female', label: Text('女')),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weight,
            decoration: const InputDecoration(labelText: '体重 (kg)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _height,
            decoration: const InputDecoration(labelText: '身高 (cm)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _age,
            decoration: const InputDecoration(labelText: '年龄'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          const Text('活动系数', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _activityChip('久坐', 1.2),
              _activityChip('轻度', 1.375),
              _activityChip('中度', 1.55),
              _activityChip('高度', 1.725),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              final w = double.tryParse(_weight.text);
              final h = double.tryParse(_height.text);
              final a = int.tryParse(_age.text);
              if (w == null || h == null || a == null) return;
              final bmr = CalorieRepository.bmr(
                gender: _gender, weightKg: w, heightCm: h, age: a,
              );
              _target.text = (bmr * _activity).round().toString();
              setState(() {});
            },
            child: Text('用 Mifflin-St Jeor 算一下（×$_activity）'),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _target,
            decoration: const InputDecoration(labelText: '每日目标 kcal'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              final t = int.tryParse(_target.text);
              if (t == null) return;
              await ref.read(calorieRepoProvider).setTarget(t);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
