import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';

import '../providers/location_reminder_providers.dart';

class LocationReminderAddPage extends ConsumerStatefulWidget {
  const LocationReminderAddPage({super.key});

  @override
  ConsumerState<LocationReminderAddPage> createState() => _AddPageState();
}

class _AddPageState extends ConsumerState<LocationReminderAddPage> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  double? _lat;
  double? _lng;
  int _radius = 200;
  String _trigger = 'enter';
  bool _locating = false;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final loc = Location();
    if (!await loc.serviceEnabled()) {
      await loc.requestService();
    }
    var perm = await loc.hasPermission();
    if (perm == PermissionStatus.denied) {
      perm = await loc.requestPermission();
    }
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
      _lat = pos.latitude;
      _lng = pos.longitude;
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
          ElevatedButton.icon(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_locating ? '定位中...' : '用当前位置'),
          ),
          if (_lat != null && _lng != null) ...[
            const SizedBox(height: 8),
            Text('已选：$_lat, $_lng',
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
            onPressed: _lat == null
                ? null
                : () async {
                    await ref.read(locationReminderRepoProvider).add(
                          title: _title.text,
                          placeName: _place.text,
                          lat: _lat!,
                          lng: _lng!,
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
