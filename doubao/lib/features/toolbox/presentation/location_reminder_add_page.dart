import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../data/loc_notification_service.dart';
import '../providers/location_reminder_providers.dart';

class LocationReminderAddPage extends ConsumerStatefulWidget {
  const LocationReminderAddPage({super.key});

  @override
  ConsumerState<LocationReminderAddPage> createState() => _AddPageState();
}

class _AddPageState extends ConsumerState<LocationReminderAddPage> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  LatLng? _selected;
  LatLng _center = const LatLng(39.9087, 116.3975);
  int _radius = 200;
  String _trigger = 'enter';
  bool _locating = false;
  bool _showManual = false;

  @override
  void initState() {
    super.initState();
    _initCenter();
    // 前台 Activity 在场时申请通知权限（后台 TaskHandler 无法申请，
    // 插件 requestNotificationsPermission 在无 Activity 时抛 NPE）
    LocNotificationService()
        .requestPermissionFromForeground()
        .catchError((Object _) {});
  }

  Future<void> _initCenter() async {
    final loc = Location();
    try {
      final pos = await loc.getLocation();
      if (pos.latitude != null && pos.longitude != null && mounted) {
        setState(() => _center = LatLng(pos.latitude!, pos.longitude!));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final loc = Location();
    if (!await loc.serviceEnabled()) await loc.requestService();
    var perm = await loc.hasPermission();
    if (perm == PermissionStatus.denied) perm = await loc.requestPermission();
    if (perm != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('定位权限被拒，无法用当前位置')),
        );
      }
      setState(() => _locating = false);
      return;
    }
    final pos = await loc.getLocation();
    setState(() {
      _selected = LatLng(pos.latitude!, pos.longitude!);
      _center = _selected!;
      _locating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加途径提醒')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '提醒内容（如：顺便买菜）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _place,
            decoration: const InputDecoration(labelText: '地点名（如：家附近超市）'),
          ),
          const SizedBox(height: 16),
          // 地图
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 300,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 15,
                  onTap: (tapPos, latlng) => setState(() => _selected = latlng),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.efficiency.app',
                  ),
                  if (_selected != null)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: _selected!,
                        radius: _radius.toDouble(),
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 1,
                      ),
                    ]),
                  if (_selected != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _selected!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showManual = !_showManual),
              icon: const Icon(Icons.edit_location_alt),
              label: Text(_showManual ? '收起手动输入' : '地图加载慢？手动输入经纬度'),
            ),
          ),
          if (_showManual) ...[
            TextField(
              controller: _latCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '纬度（如 32.63）'),
            ),
            TextField(
              controller: _lngCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '经度（如 117.98）'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () {
                final lat = double.tryParse(_latCtrl.text);
                final lng = double.tryParse(_lngCtrl.text);
                if (lat != null && lng != null) {
                  setState(() {
                    _selected = LatLng(lat, lng);
                    _center = LatLng(lat, lng);
                  });
                }
              },
              child: const Text('应用坐标'),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_locating ? '定位中...' : '用当前位置'),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 8),
            Text('已选：${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: '半径'),
            value: _radius,
            items: [100, 200, 500, 1000]
                .map((r) => DropdownMenuItem(value: r, child: Text('${r}m')))
                .toList(),
            onChanged: (v) => setState(() => _radius = v!),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'enter', label: Text('进入时提醒')),
              ButtonSegment(value: 'exit', label: Text('离开时提醒')),
            ],
            selected: {_trigger},
            onSelectionChanged: (s) => setState(() => _trigger = s.first),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () async {
                    await ref.read(locationReminderRepoProvider).add(
                          title: _title.text,
                          placeName: _place.text,
                          lat: _selected!.latitude,
                          lng: _selected!.longitude,
                          radius: _radius,
                          triggerOn: _trigger,
                        );
                    if (mounted) Navigator.of(context).pop();
                  },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
