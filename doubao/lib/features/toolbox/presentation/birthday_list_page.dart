import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../data/birthday_repository.dart';
import '../providers/birthday_providers.dart';
import 'birthday_add_page.dart';

class BirthdayListPage extends ConsumerWidget {
  const BirthdayListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(birthdaysProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('朋友生日')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BirthdayAddPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cake_outlined, size: 48, color: AppColors.neutral),
                  SizedBox(height: 12),
                  Text('还没有记录生日',
                      style: TextStyle(fontSize: 16, color: AppColors.neutral)),
                  SizedBox(height: 6),
                  Text('点右下角 + 记一个，提前提醒你',
                      style: TextStyle(fontSize: 13, color: AppColors.neutral)),
                ],
              ),
            );
          }
          // 按距离天数排序
          final now = DateTime.now();
          final sorted = [...list]
            ..sort((a, b) => BirthdayRepository.daysUntilNext(a, now)
                .compareTo(BirthdayRepository.daysUntilNext(b, now)));
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (_, i) => _Row(b: sorted[i], now: now),
          );
        },
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  final BirthdayRow b;
  final DateTime now;
  const _Row({required this.b, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = BirthdayRepository.daysUntilNext(b, now);
    final soon = days <= 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soon ? Colors.orange.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              b.name.isNotEmpty ? b.name[0] : '?',
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  b.calendarType == 'lunar'
                      ? '农历 ${b.birthdayMonth}月${b.birthdayDay}日'
                      : '公历 ${b.birthdayMonth}月${b.birthdayDay}日',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral),
                ),
                const SizedBox(height: 4),
                Chip(
                  label: Text(b.groupTag, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                days == 0 ? '今天' : '还剩 $days 天',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: soon ? Colors.orange : AppColors.neutral,
                ),
              ),
              Text(
                '提前${b.advanceDays}天提醒',
                style: const TextStyle(fontSize: 11, color: AppColors.neutral),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
