import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/location_reminder.dart';
import '../providers/location_providers.dart';
import 'location_edit_page.dart';

/// 途径提醒（工具箱插件 4）。
///
/// 状态提示很重要：定位权限没给时，**所有提醒都不会触发**。
/// 所以页面顶部常驻一条状态条，明确告诉用户现在能不能用（D4/D5）。
class LocationReminderListPage extends ConsumerWidget {
  const LocationReminderListPage({super.key});

  Future<void> _checkPermission(BuildContext context, WidgetRef ref) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    if (!context.mounted) return;

    // R4：点「开启」= 用户主动要求监测，解除暂停标记并按实际情况起服务
    final monitor = ref.read(locationMonitorProvider);
    await monitor.resumeByUserAction();
    if (!context.mounted) return;

    final background = monitor.serviceRunning;
    final foregroundOnly = ref.read(locationWatcherProvider).isRunning;
    final started = background || foregroundOnly;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            !started
                ? '定位仍不可用：请到系统设置里允许「位置信息」'
                : background
                ? '后台监测已开启：每 60 秒检查一次，App 关掉也有效'
                : '定位已就绪：每 30 秒检查一次（仅 App 打开时有效）',
          ),
          action: started
              ? null
              : const SnackBarAction(
                  label: '去设置',
                  onPressed: Geolocator.openAppSettings,
                ),
        ),
      );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LocationReminder reminder,
  ) async {
    final repo = ref.read(locationRepositoryProvider);
    await repo.softDelete(reminder.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '已删除「${reminder.placeName.isEmpty ? reminder.title : reminder.placeName}」',
          ),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => repo.restore(reminder.id),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncList = ref.watch(locationRemindersProvider);
    final reminders = asyncList.value ?? const <LocationReminder>[];

    final Widget body;
    if (asyncList.hasError && !asyncList.hasValue) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '提醒数据读取失败',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppDimens.sectionHeaderGap),
            FilledButton(
              onPressed: () => ref.invalidate(locationRemindersProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    } else if (!asyncList.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (reminders.isEmpty) {
      body = const EmptyState(
        icon: Icons.place_outlined,
        title: '还没有地点提醒',
        subtitle: '点右下角添加：走到超市附近就提醒你买菜',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.only(
          top: AppDimens.chipGap,
          bottom: AppDimens.sectionGap * 2,
        ),
        children: [
          const AppSectionHeader(
            '我的地点',
            subtitle: '后台每 60 秒检查一次，App 关掉也有效；同一地点 24 小时内只提醒一次',
          ),
          for (final r in reminders)
            _ReminderCard(
              reminder: r,
              onToggle: (v) async {
                await ref
                    .read(locationRepositoryProvider)
                    .setEnabled(r.id, v);
                if (!v) return;
                // 重新打开一条 = 用户又要监测了，解除「通知被划掉」的暂停
                await ref.read(locationMonitorProvider).resumeByUserAction();
              },
              onDelete: () => _delete(context, ref, r),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Semantics(namesRoute: true, child: const Text('途径提醒')),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: '定位权限 / 立即检查',
            onPressed: () => _checkPermission(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const LocationEditPage()),
        ),
        icon: const ExcludeSemantics(
          child: Icon(Icons.add_location_alt_outlined),
        ),
        label: const Text('添加提醒'),
      ),
      body: Column(
        children: [
          _PermissionBanner(onFix: () => _checkPermission(context, ref)),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// 权限/定位服务状态条：只有"已就绪"才是绿色。
class _PermissionBanner extends ConsumerStatefulWidget {
  const _PermissionBanner({required this.onFix});

  final VoidCallback onFix;

  @override
  ConsumerState<_PermissionBanner> createState() => _PermissionBannerState();
}

class _PermissionBannerState extends ConsumerState<_PermissionBanner> {
  bool? _serviceOn;
  LocationPermission? _permission;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        _serviceOn = service;
        _permission = permission;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serviceOn = false;
        _permission = LocationPermission.denied;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready =
        _serviceOn == true &&
        (_permission == LocationPermission.whileInUse ||
            _permission == LocationPermission.always);

    // 后台监测状态（服务 / 前台兜底 / 用户划掉通知后的暂停）
    final monitor = ref.watch(locationMonitorProvider);
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final String text;
        var warn = false;
        if (_serviceOn == null) {
          text = '正在检查定位权限…';
        } else if (_serviceOn == false) {
          text = '系统定位服务已关闭 —— 提醒不会触发';
          warn = true;
        } else if (!ready) {
          text = _permission == LocationPermission.deniedForever
              ? '定位权限被永久拒绝 —— 请到系统设置里开启'
              : '还没给定位权限 —— 提醒不会触发';
          warn = true;
        } else if (monitor.enabledCount == 0) {
          text = '定位已就绪 · 添加一条地点提醒后开始后台监测';
        } else if (monitor.serviceRunning) {
          text =
              '后台监测中：${monitor.enabledCount} 个地点，每 60 秒检查一次（App 关掉也有效）';
        } else if (monitor.userPaused) {
          text = '后台监测已暂停（常驻通知被划掉）· 仅 App 打开时每 30 秒检查';
          warn = true;
        } else {
          text = '仅前台监测（后台服务未启动）· App 打开时每 30 秒检查';
          warn = true;
        }

        final color = warn || !ready ? AppColors.warning : AppColors.success;

        return Container(
          margin: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.chipGap,
            AppDimens.pagePadding,
            0,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.cardGap,
            vertical: AppDimens.chipGap,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          ),
          child: Row(
            children: [
              Icon(
                warn || !ready
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                size: 18,
                color: color,
              ),
              const SizedBox(width: AppDimens.chipGap),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
              if (!ready)
                TextButton(
                  onPressed: () {
                    widget.onFix();
                    _refresh();
                  },
                  child: const Text('开启'),
                )
              else if (monitor.enabledCount > 0 && !monitor.serviceRunning)
                TextButton(
                  onPressed: () async {
                    await monitor.resumeByUserAction();
                    await _refresh();
                  },
                  child: const Text('恢复'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
  });

  final LocationReminder reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = reminder.placeName.isEmpty ? '未命名地点' : reminder.placeName;

    return Dismissible(
      key: ValueKey('location-${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppDimens.pagePadding),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.chipGap,
            AppDimens.chipGap,
            AppDimens.chipGap,
          ),
          child: Row(
            children: [
              AppModuleIcon(
                reminder.triggerOn == TriggerOn.enter
                    ? Icons.login
                    : Icons.logout,
                color: reminder.enabled
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
              const SizedBox(width: AppDimens.cardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: reminder.enabled ? null : theme.disabledColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$place · ${reminder.triggerOn.label} · ${reminder.radiusMeters}m'
                      '${reminder.notifiedAt == null ? '' : ' · 上次提醒 ${_timeAgo(reminder.notifiedAt!)}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: reminder.enabled, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    return '${d.inDays} 天前';
  }
}
