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
///
/// **定位（PHONE-FIX-1）**：用户真机反馈「能打开地图但是无法获取定位」。
/// 原实现只在点右上角图标时才定位，且整段包在 `try { … } catch (_) {}` 里 ——
/// 室内 GPS 10 秒拿不到 fix 就抛超时，异常被吞掉，界面毫无反馈，
/// 用户只能看到一张停在北京的地图。现在：
/// 1. **进页面就自动定位一次**（已有坐标时不抢用户的选择）；
/// 2. **降级链**：`getCurrentPosition(8s)` → `getLastKnownPosition()`；
/// 3. **不静默**：服务没开 / 没权限 / 拿不到，都在地图上留一条可读的常驻提示；
/// 4. 拿到位置就落一个蓝点标记，中心点跟着走。
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

  /// 实时定位的等待上限。室内冷启动经常 10 秒都拿不到 fix，
  /// 与其让用户盯着转圈，不如早点降级到「上次已知位置」。
  static const Duration _fixTimeout = Duration(seconds: 8);

  late LatLng _center;

  /// 瓦片加载失败（离线 / 被墙 / 无网）：显示降级提示，地图仍可拖动粗定位。
  bool _tilesFailed = false;

  /// 正在定位（右上角图标转圈）
  bool _locating = false;

  /// 我的位置（拿到才落蓝点）
  LatLng? _myLocation;
  double? _accuracyMeters;

  /// 常驻的定位提示（null = 一切正常）。**不用 SnackBar**：
  /// SnackBar 几秒就消失，用户还没看清就没了，而"为什么没有定位"需要一直看得见。
  String? _geoNotice;

  /// 地图是否已就绪（`_map.move` 在 onMapReady 之前调用会抛）
  bool _mapReady = false;

  /// 地图未就绪时暂存的目标中心，onMapReady 时再补一次移动
  LatLng? _pendingMove;

  /// 进页面只自动定位一次（避免回调重复触发）
  bool _autoLocated = false;

  bool get _hasInitialCoords =>
      widget.initialLatitude != null && widget.initialLongitude != null;

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLatitude;
    final lon = widget.initialLongitude;
    _center = (lat != null && lon != null) ? LatLng(lat, lon) : _fallback;

    // 首帧之后再定位：此时地图已建立，`_map.move` 才不会撞上未就绪的控制器。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoLocated) return;
      _autoLocated = true;
      // 已有坐标（用户上次选的 / 手动填的）就不抢中心点，只是顺手拿一下
      // 当前位置好在地图上标出来；没有坐标则直接把地图移到当前位置。
      _locate(moveMap: !_hasInitialCoords);
    });
  }

  /// 定位：服务开关 → 权限 → 实时定位 → 上次已知位置，逐级降级。
  ///
  /// 每一级失败都写一条**用户能看懂**的提示，绝不静默返回。
  Future<void> _locate({required bool moveMap}) async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      // 1) 定位服务总开关。关着的时候权限检查会「通过」但没有数据，
      //    不先问这一句，用户只会看到一个永远转圈的定位按钮。
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setNotice(
          '手机的「位置信息」没有打开。到系统设置里打开后点右上角重新定位，'
          '或直接拖动地图选点。',
        );
        return;
      }

      // 2) 权限
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setNotice(
          '还没有授予定位权限。可以再点一次右上角图标授权，'
          '或直接拖动地图选点。',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setNotice(
          '定位权限被永久拒绝。请到「设置 → 应用 → 权限 → 位置信息」里打开，'
          '或直接拖动地图选点。',
        );
        return;
      }

      // 3) 实时定位（室内 / 冷启动常常超时）
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: _fixTimeout,
          ),
        );
      } catch (_) {
        pos = null; // 交给下一级，不在这里吞掉了事
      }

      // 4) 降级：上一次已知位置。室内通常是几分钟前的点，够用作地图起点。
      if (pos == null) {
        try {
          pos = await Geolocator.getLastKnownPosition();
        } catch (_) {
          pos = null;
        }
      }

      if (!mounted) return;

      if (pos == null) {
        _setNotice(
          '暂时无法获取定位（可能在室内或信号弱）。'
          '可以直接拖动地图选点，或点下方「输入坐标」手动填写。',
        );
        return;
      }

      final target = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myLocation = target;
        _accuracyMeters = pos!.accuracy;
        _geoNotice = null;
      });
      if (moveMap) _moveMap(target);
    } catch (e) {
      // 兜底：任何没预料到的异常也要变成一句人话，而不是「点了没反应」
      _setNotice(
        '定位失败：${_shortError(e)}。可以拖动地图选点，'
        '或点「输入坐标」手动填写。',
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// 移动地图中心：控制器未就绪时先记下来，onMapReady 再补。
  void _moveMap(LatLng target) {
    setState(() => _center = target);
    if (!_mapReady) {
      _pendingMove = target;
      return;
    }
    _map.move(target, 16);
  }

  void _setNotice(String message) {
    if (!mounted) return;
    setState(() {
      _geoNotice = message;
      _locating = false;
    });
  }

  /// 异常 → 一句短说明（Geolocator 的异常 toString 很长，塞进横幅会撑爆）
  static String _shortError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    const maxChars = 60;
    if (raw.isEmpty) return '未知原因';
    return raw.length > maxChars ? '${raw.substring(0, maxChars)}…' : raw;
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
              if (lat == null ||
                  lon == null ||
                  lat.abs() > 90 ||
                  lon.abs() > 180) {
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
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            tooltip: _locating ? '正在定位…' : '定位到我的位置',
            onPressed: _locating ? null : () => _locate(moveMap: true),
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
              onMapReady: () {
                _mapReady = true;
                final pending = _pendingMove;
                if (pending != null) {
                  _pendingMove = null;
                  _map.move(pending, 16);
                }
              },
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
              // 我的位置：光晕 + 蓝点（拿到位置才画）
              // 为什么带一圈 44dp 的光晕：地图定位后中心点正好压着我的位置，
              // 准星（红色图钉）会把 22dp 的小蓝点整个盖住，用户看不出"定位成功了"。
              // 光晕比准星大一圈，红蓝叠在一起也能一眼分辨。
              if (_myLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLocation!,
                      width: 44,
                      height: 44,
                      child: const _MyLocationDot(),
                    ),
                  ],
                ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          // 提示条：定位问题优先，其次瓦片问题。都常驻，直到状态改变。
          Positioned(
            top: AppDimens.chipGap,
            left: AppDimens.pagePadding,
            right: AppDimens.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_geoNotice != null) ...[
                  _NoticeBanner(
                    icon: Icons.location_off_outlined,
                    color: AppColors.warning,
                    text: _geoNotice!,
                    onRetry: _locating ? null : () => _locate(moveMap: true),
                  ),
                  const SizedBox(height: AppDimens.chipGap),
                ],
                if (_tilesFailed)
                  _NoticeBanner(
                    icon: Icons.cloud_off,
                    color: AppColors.warning,
                    text:
                        '地图瓦片加载失败（设备无网络）。仍可拖动准星粗定位，'
                        '或点下方「输入坐标」精确填写。',
                  ),
              ],
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
                    const SizedBox(height: 2),
                    // 定位状态说清楚：拿到就报精度，没拿到已经在上面横幅里说了
                    Text(
                      _locating
                          ? '正在获取当前位置…'
                          : _myLocation != null
                          ? '已定位到你当前位置'
                                '${_accuracyMeters != null ? '（精度约 ${_accuracyMeters!.round()}m）' : ''}'
                          : '还没取到当前位置，可拖动地图或输入坐标',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _myLocation != null
                            ? AppColors.success
                            : theme.colorScheme.onSurfaceVariant,
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

/// 地图上的"我的位置"标记：半透明光晕 + 白边蓝心。
///
/// 光晕是必需的，不是装饰：定位成功后地图中心 = 我的位置，红色准星正好压在上面，
/// 只有 22dp 的小蓝点会被完全遮住，看起来像"没定位到"。
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 光晕
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.active.withValues(alpha: 0.18),
            ),
          ),
          // 蓝点
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.active,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(blurRadius: 4, color: Colors.black38),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 常驻提示条：图标 + 说明 + 可选「重试」。
class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.icon,
    required this.color,
    required this.text,
    this.onRetry,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.cardGap,
        vertical: AppDimens.chipGap,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: AppDimens.chipGap),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.black87,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.chipGap,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}
