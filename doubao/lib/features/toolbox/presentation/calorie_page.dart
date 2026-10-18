import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../data/calorie_repository.dart';
import '../providers/calorie_providers.dart';
import 'calorie_target_page.dart';

class CaloriePage extends ConsumerStatefulWidget {
  const CaloriePage({super.key});

  @override
  ConsumerState<CaloriePage> createState() => _CaloriePageState();
}

class _CaloriePageState extends ConsumerState<CaloriePage> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  List<String> _hints = [];

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    super.dispose();
  }

  Future<void> _onNameChanged(String v) async {
    if (v.length < 1) {
      setState(() => _hints = []);
      return;
    }
    final h = await ref.read(calorieRepoProvider).historyNames(v);
    if (mounted) setState(() => _hints = h.take(5).toList());
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(todayCaloriesProvider);
    final target = ref.watch(calorieTargetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('每日热量'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CalorieTargetPage()),
            ),
          ),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
        data: (list) {
          final total = list.fold<int>(0, (s, e) => s + e.kcal);
          final p = target.valueOrNull ?? 2000;
          final protein = list.fold<double>(0, (s, e) => s + e.proteinG);
          final carb = list.fold<double>(0, (s, e) => s + e.carbG);
          final fat = list.fold<double>(0, (s, e) => s + e.fatG);

          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_outlined, size: 48, color: AppColors.neutral),
                  SizedBox(height: 12),
                  Text('今天还没记',
                      style: TextStyle(fontSize: 16, color: AppColors.neutral)),
                  SizedBox(height: 6),
                  Text('先设目标，或直接开始记',
                      style: TextStyle(fontSize: 13, color: AppColors.neutral)),
                ],
              ),
            );
          }

          // 按餐次分组
          final groups = <String, List<CalorieEntryRow>>{};
          for (final e in list) {
            groups.putIfAbsent(e.meal, () => []).add(e);
          }

          return Column(
            children: [
              // 概览
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('$total / $p kcal',
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (total / p).clamp(0.0, 1.0),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text('蛋白 ${protein.toStringAsFixed(0)}g · 碳水 ${carb.toStringAsFixed(0)}g · 脂肪 ${fat.toStringAsFixed(0)}g',
                        style: const TextStyle(fontSize: 12, color: AppColors.neutral)),
                  ],
                ),
              ),
              // 列表
              Expanded(
                child: ListView(
                  children: groups.entries.expand((g) {
                    final sum = g.value.fold<int>(0, (s, e) => s + e.kcal);
                    return [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(CalorieRepository.mealLabel(g.key),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('$sum kcal',
                                style: const TextStyle(color: AppColors.neutral, fontSize: 12)),
                          ],
                        ),
                      ),
                      ...g.value.map((e) => Slidable(
                            endActionPane: ActionPane(
                              motion: const BehindMotion(),
                              children: [
                                SlidableAction(
                                  icon: Icons.delete,
                                  backgroundColor: Colors.red,
                                  onPressed: (_) =>
                                      ref.read(calorieRepoProvider).softDelete(e.id),
                                ),
                              ],
                            ),
                            child: ListTile(
                              title: Text(e.name),
                              trailing: Text('${e.kcal} kcal'),
                            ),
                          )),
                    ];
                  }).toList(),
                ),
              ),
              // 快速添加
              Padding(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  children: [
                    if (_hints.isNotEmpty)
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _hints
                              .map((h) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ActionChip(
                                      label: Text(h),
                                      onPressed: () {
                                        _name.text = h;
                                        setState(() => _hints = []);
                                      },
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _name,
                            decoration: const InputDecoration(hintText: '食物名'),
                            onChanged: _onNameChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _kcal,
                            decoration: const InputDecoration(hintText: 'kcal'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, size: 32),
                          onPressed: () async {
                            final n = _name.text.trim();
                            final k = int.tryParse(_kcal.text.trim());
                            if (n.isEmpty || k == null) return;
                            await ref.read(calorieRepoProvider).add(
                                  name: n,
                                  kcal: k,
                                  meal: CalorieRepository.autoMeal(),
                                );
                            _name.clear();
                            _kcal.clear();
                            setState(() => _hints = []);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
