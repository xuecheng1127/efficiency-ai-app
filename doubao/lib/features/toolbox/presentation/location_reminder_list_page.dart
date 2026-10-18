import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../data/loc_notification_service.dart';
import '../data/location_fg_service.dart';
import '../data/location_foreground_service.dart';
import '../data/location_reminder_monitor.dart';
import '../data/location_reminder_repository.dart';
import '../providers/location_reminder_providers.dart';
import 'location_reminder_add_page.dart';

class LocationReminderListPage extends ConsumerStatefulWidget {
  const LocationReminderListPage({super.key});

  @override
  ConsumerState<LocationReminderListPage> createState() => _ListPageState();
}

class _ListPageState extends ConsumerState<LocationReminderListPage> {
  LocationReminderMonitor? _monitor;

  @override
  void initState() {
    super.initState();
    LocNotificationService().init();
    _monitor = LocationReminderMonitor(ref.read(locationReminderRepoProvider));
    _monitor!.onTrigger = (r, d) {
      LocNotificationService().show(
        id: r.id,
        title: '途径提醒',
        body: '你正在【${r.placeName}】附近 —— ${r.title}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📍 途径提醒 · 你正在【${r.placeName}】附近 —— ${r.title}')),
      );
    };
    _monitor!.start();
  }

  @override
  void dispose() {
    _monitor?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(locationRemindersProvider);
    final bgEnabled = ref.watch(locationBgEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('途径提醒'),
        actions: [
          Row(
            children: [
              const Text('后台监控', style: TextStyle(fontSize: 12)),
              Switch(
                value: bgEnabled,
                onChanged: (v) async {
                  await ref.read(locationBgEnabledProvider.notifier).set(v);
                  if (v) {
                    await LocationFgService.init();
                    await LocationFgService.start(AppDatabase.instance);
                  } else {
                    await LocationFgService.stop();
                  }
                },
              ),
            ],
          ),
        ],
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
                Text('${r.placeName} · 半径${r.radiusMeters}m',
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral)),
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
