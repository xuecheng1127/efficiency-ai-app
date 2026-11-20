import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../data/loc_notification_service.dart';
import '../data/location_reminder_fg_service.dart';
import '../providers/location_reminder_providers.dart';
import 'location_reminder_add_page.dart';

class LocationReminderListPage extends ConsumerStatefulWidget {
  const LocationReminderListPage({super.key});

  @override
  ConsumerState<LocationReminderListPage> createState() => _ListPageState();
}

class _ListPageState extends ConsumerState<LocationReminderListPage> {
  @override
  void initState() {
    super.initState();
    LocNotificationService().init();
    // 页面打开时同步一次服务状态（App 启动后首次进入即恢复监测）。
    // 位置检查统一由 LocationReminderFgService 的后台 TaskHandler 负责
    // （60s 轮询 + 进入/离开状态机），页面本身不再起轮询。
    LocationReminderFgService.sync();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(locationRemindersProvider);

    // 数据变化（增/删/开关）时同步服务启停与常驻通知数字
    ref.listen(locationRemindersProvider, (_, __) {
      LocationReminderFgService.sync();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('途径提醒'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LocationReminderAddPage()),
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
                  Icon(Icons.location_on_outlined, size: 48, color: AppColors.neutral),
                  SizedBox(height: 12),
                  Text('还没有途径提醒',
                      style: TextStyle(fontSize: 16, color: AppColors.neutral)),
                  SizedBox(height: 6),
                  Text('设一个，走到那儿自动提醒你',
                      style: TextStyle(fontSize: 13, color: AppColors.neutral)),
                ],
              ),
            );
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) => _Row(r: list[i]),
          );
        },
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  final LocationReminderRow r;
  const _Row({required this.r});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(locationReminderRepoProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Icon(Icons.location_on, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  '${r.placeName} · 半径${r.radiusMeters}m · ${r.triggerOn == 'exit' ? '离开时' : '进入时'}提醒',
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral),
                ),
              ],
            ),
          ),
          Switch(
            value: r.enabled == 1,
            onChanged: (v) => repo.setEnabled(r.id, v),
          ),
        ],
      ),
    );
  }
}
