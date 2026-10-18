import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

/// 地图选点：拖动地图，**屏幕中心**就是选中的位置。
///
/// 为什么是"中心点"而不是"点地图上的图钉"：
/// 手指点哪里会被手指挡住，而中心十字准星始终可见 —— 选地点这种精确操作更可靠。
///
/// 瓦片用 OpenStreetMap 公共瓦片（无需 API Key）；`userAgentPackageName` 是
/// OSM 使用条款要求的最小标识，别删。
class LocationMapPickerPage extends StatefulWidget {
  const LocationMapPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<LocationMapPickerPage> createState() => _LocationMapPickerPageState();
}

class _LocationMapPickerPageState extends State<LocationMapPickerPage> {
  final MapController _map = MapController();

  /// 默认落点：传入的坐标 → 北京天安门（无定位时的兜底，不弹权限）
  static const LatLng _fallback = LatLng(39.908722, 116.397499);

  late LatLng _center;

  /// 瓦片加载失败（离线 / 被墙 / 无网）：显示降级提示，地图仍可拖动粗定位。
  bool _tilesFailed = false;

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLatitude;
    final lon = widget.initialLongitude;
    _center = (lat != null && lon != null) ? LatLng(lat, lon) : _fallback;
  }

  Future<void> _locateMe() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('没有定位权限，先手动拖动地图吧')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final target = LatLng(pos.latitude, pos.longitude);
      _map.move(target, 16);
      if (!mounted) return;
      setState(() => _center = target);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('定位失败，可以手动拖动地图')));
    }
  }

  /// 离线兜底：直接输入经纬度（地图要联网才有瓦片）。
  Future<void> _enterCoordsManually() async {
    final latCtrl = TextEditingController(
      text: _center.latitude.toStringAsFixed(6),
    );
    final lonCtrl = TextEditingController(
      text: _center.longitude.toStringAsFixed(6),
    );
    final result = await showDialog<LatLng>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('输入坐标'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '纬度'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lonCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '经度'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latCtrl.text.trim());
              final lon = double.tryParse(lonCtrl.text.trim());
              if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
                return;
              }
              Navigator.pop(dialogContext, LatLng(lat, lon));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    latCtrl.dispose();
    lonCtrl.dispose();
    if (result == null || !mounted) return;
    _map.move(result, 16);
    setState(() => _center = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('地图选点'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: '回到我的位置',
            onPressed: _locateMe,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (camera, _) {
                // 拖动/缩放时更新中心点（这就是"选中的位置"）
                setState(() => _center = camera.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.efficiency.app.efficiency_app',
                maxNativeZoom: 19,
                errorTileCallback: (_, _, _) {
                  if (_tilesFailed || !mounted) return;
                  // 第一张瓦片失败就提示（不刷屏）
                  setState(() => _tilesFailed = true);
                },
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (_tilesFailed)
            Positioned(
              top: AppDimens.chipGap,
              left: AppDimens.pagePadding,
              right: AppDimens.pagePadding,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.cardGap,
                  vertical: AppDimens.chipGap,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, size: 18, color: Colors.black87),
                    const SizedBox(width: AppDimens.chipGap),
                    Expanded(
                      child: Text(
                        '地图瓦片加载失败（设备无网络）。仍可拖动准星粗定位，'
                        '或点下方「输入坐标」精确填写。',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 中心十字准星：必须指向"当前中心"，不随手指位置漂移
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.place,
                    size: 40,
                    color: AppColors.danger,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black38)],
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 底部：坐标 + 确认
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimens.cardRadius),
                ),
                boxShadow: const [
                  BoxShadow(blurRadius: 12, color: Colors.black26),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.cardGap,
                AppDimens.pagePadding,
                AppDimens.cardGap,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '拖动地图，让准星落在目标地点'
                      '${_tilesFailed ? '（瓦片需联网）' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '看不到地图？点「输入坐标」直接填经纬度。',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppDimens.chipGap),
                    Text(
                      '${_center.latitude.toStringAsFixed(6)}, '
                      '${_center.longitude.toStringAsFixed(6)}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppDimens.cardGap),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _enterCoordsManually,
                          icon: const Icon(Icons.keyboard, size: 18),
                          label: const Text('输入坐标'),
                        ),
                        const SizedBox(width: AppDimens.chipGap),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context, _center),
                            icon: const Icon(Icons.check),
                            label: const Text('用这个位置'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
