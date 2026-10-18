import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/notifications/app_notifications.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/location_reminder.dart';
import '../providers/location_providers.dart';
import 'location_map_picker_page.dart';

enum _PickMode { current, manual, map }

/// 添加途径提醒。
///
/// 两种定位方式（规格要求）：
/// - **用当前位置**：一次点击，最简单；
/// - **手动输入经纬度**：没有 GPS / 想设远方地点时用。
///
/// 如实标注：**没有做「拖地图选点」** —— 需要引入地图 SDK（flutter_map / Google Maps）
/// 与瓦片服务，本轮没有加依赖；用手输入替代，并在页面上写明。
class LocationEditPage extends ConsumerStatefulWidget {
  const LocationEditPage({super.key});

  @override
  ConsumerState<LocationEditPage> createState() => _LocationEditPageState();
}

class _LocationEditPageState extends ConsumerState<LocationEditPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _place = TextEditingController();
  final TextEditingController _lat = TextEditingController();
  final TextEditingController _lon = TextEditingController();

  TriggerOn _trigger = TriggerOn.enter;
  double _radius = 200;
  _PickMode _mode = _PickMode.current;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('系统定位服务未开启'),
            action: SnackBarAction(
              label: '去开启',
              onPressed: Geolocator.openLocationSettings,
            ),
          ),
        );
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('没有定位权限，无法读取当前位置'),
            action: SnackBarAction(
              label: '去设置',
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
      return false;
    }
    return true;
  }

  Future<void> _useCurrent() async {
    setState(() => _locating = true);
    try {
      if (!await _ensurePermission()) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lon.text = pos.longitude.toStringAsFixed(6);
        if (_place.text.trim().isEmpty) _place.text = '当前位置';
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '已取到坐标：${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
              '（精度约 ${pos.accuracy.round()}m）',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '取位置失败：$e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// 地图选点：打开地图页，返回中心坐标。
  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationMapPickerPage(
          initialLatitude: double.tryParse(_lat.text.trim()),
          initialLongitude: double.tryParse(_lon.text.trim()),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lat.text = picked.latitude.toStringAsFixed(6);
      _lon.text = picked.longitude.toStringAsFixed(6);
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    if (title.isEmpty) {
      setState(() => _error = '写一句提醒内容（比如「买菜」）');
      return;
    }
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      setState(() => _error = '还没有有效坐标：点「用当前位置」，或手动填经纬度');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(locationRepositoryProvider);
    final id = await repo.create(
      title: title,
      placeName: _place.text,
      latitude: lat,
      longitude: lon,
      radiusMeters: _radius.round(),
      triggerOn: _trigger,
    );
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：检查一下坐标范围';
      });
      return;
    }

    // 提醒要发通知 → 在这里做场景化权限申请
    await AppNotifications.ensurePermission();
    final watcher = ref.read(locationWatcherProvider);
    await watcher.start();
    // **不等**这一拍定位：保存是本地写库，不该被 GPS 拖住 10 秒。
    // 触发结果会通过通知 / 全局 SnackBar 告诉用户。
    unawaited(watcher.checkNow());

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加：${_place.text.trim().isEmpty ? title : _place.text.trim()}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('添加途径提醒')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
        children: [
          const AppSectionHeader('提醒什么'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.pagePadding,
              vertical: AppDimens.cardPadding,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(Icons.notifications_active_outlined),
                    hintText: '提醒内容（必填），如「买菜」',
                  ),
                ),
                const Divider(height: 1),
                TextField(
                  controller: _place,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    icon: Icon(Icons.storefront_outlined),
                    hintText: '地点名（可留空），如「永辉超市」',
                  ),
                ),
              ],
            ),
          ),
          const AppSectionHeader('什么时候提醒'),
          AppCard(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<TriggerOn>(
                  segments: const [
                    ButtonSegment(
                      value: TriggerOn.enter,
                      label: Text('到达时'),
                      icon: Icon(Icons.login),
                    ),
                    ButtonSegment(
                      value: TriggerOn.exit,
                      label: Text('离开时'),
                      icon: Icon(Icons.logout),
                    ),
                  ],
                  selected: {_trigger},
                  onSelectionChanged: (v) =>
                      setState(() => _trigger = v.first),
                ),
                const SizedBox(height: AppDimens.cardGap),
                Row(
                  children: [
                    Text('触发半径', style: theme.textTheme.bodyMedium),
                    Expanded(
                      child: Slider(
                        value: _radius,
                        min: 100,
                        max: 1000,
                        divisions: 9,
                        label: '${_radius.round()} m',
                        onChanged: (v) => setState(() => _radius = v),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${_radius.round()} m',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const AppSectionHeader('在哪'),
          AppCard(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<_PickMode>(
                  segments: const [
                    ButtonSegment(
                      value: _PickMode.current,
                      label: Text('当前位置'),
                      icon: Icon(Icons.my_location),
                    ),
                    ButtonSegment(
                      value: _PickMode.map,
                      label: Text('地图选点'),
                      icon: Icon(Icons.map_outlined),
                    ),
                    ButtonSegment(
                      value: _PickMode.manual,
                      label: Text('手输坐标'),
                      icon: Icon(Icons.edit_location_alt_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (v) {
                    setState(() => _mode = v.first);
                    if (v.first == _PickMode.map) _pickOnMap();
                  },
                ),
                const SizedBox(height: AppDimens.cardGap),
                if (_mode == _PickMode.current)
                  FilledButton.tonalIcon(
                    onPressed: _locating ? null : _useCurrent,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.gps_fixed),
                    label: Text(_locating ? '定位中…' : '读取当前位置'),
                  )
                else if (_mode == _PickMode.map)
                  FilledButton.tonalIcon(
                    onPressed: _pickOnMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('打开地图选点'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lat,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '纬度',
                            hintText: '39.908722',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimens.cardGap),
                      Expanded(
                        child: TextField(
                          controller: _lon,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '经度',
                            hintText: '116.397499',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppDimens.cardGap),
                Text(
                  '当前坐标：${_lat.text.isEmpty ? '未设置' : '${_lat.text}, ${_lon.text}'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _lat.text.isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppDimens.chipGap),
                Text(
                  '地图选点用 OpenStreetMap 公共瓦片（需联网）；拖动地图让准星落在目标地点即可。',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: AppColors.danger,
                  ),
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
              label: Text(_saving ? '保存中…' : '保存提醒'),
            ),
          ),
        ],
      ),
    );
  }
}
