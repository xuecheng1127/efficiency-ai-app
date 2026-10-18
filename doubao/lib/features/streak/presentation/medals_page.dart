import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/streak_provider.dart';

class MedalsPage extends ConsumerWidget {
  const MedalsPage({super.key});

  static const _medals = [
    (3, '初露锋芒', '连续完成 3 天'),
    (7, '一周不断', '连续完成 7 天'),
    (30, '月度坚持', '连续完成 30 天'),
    (100, '百日筑基', '连续完成 100 天'),
    (365, '全年无休', '连续完成 365 天'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的勋章')),
      body: streak.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  Text('🔥 ${s.current}',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.w700, color: Colors.orange)),
                  Text('当前火花 · 最长 ${s.longest} 天',
                      style: const TextStyle(color: AppColors.neutral)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ..._medals.map((m) {
              final unlocked = s.current >= m.$1;
              return Card(
                child: ListTile(
                  leading: Icon(
                    unlocked ? Icons.emoji_events : Icons.lock_outline,
                    color: unlocked ? Colors.amber : AppColors.neutral,
                    size: 32,
                  ),
                  title: Text(m.$2,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: unlocked ? null : AppColors.neutral)),
                  subtitle: Text(unlocked
                      ? m.$3
                      : '还差 ${m.$1 - s.current} 天'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
