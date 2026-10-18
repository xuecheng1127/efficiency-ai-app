import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:location/location.dart' as loc;
import 'package:workmanager/workmanager.dart';

import '../../../core/database/app_database.dart';
import 'loc_notification_service.dart';

/// WorkManager 后台 worker：每 15 分钟取一次位置，检查途径提醒
@pragma('vm:entry-point')
void locationBgCallback() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final location = loc.Location();
      final enabled = await location.serviceEnabled();
      if (!enabled) return true;
      final perm = await location.hasPermission();
      if (perm == loc.PermissionStatus.denied) {
        final req = await location.requestPermission();
        if (req != loc.PermissionStatus.granted) return true;
      }
      final pos = await location.getLocation();
      final lat = pos.latitude;
      final lon = pos.longitude;
      if (lat == null || lon == null) return true;

      final db = AppDatabase();
      final rows = await (db.select(db.locationReminders)
            ..where((t) => t.enabled.equals(1) & t.deletedAt.isNull()))
          .get();

      for (final r in rows) {
        final dx = (lat - r.latitude) * 111000;
        final dy = (lon - r.longitude) * 111000 * 0.86;
        final dist = (dx * dx + dy * dy);
        if (dist < r.radiusMeters * r.radiusMeters) {
          // 24 小时防重复
          final last = r.notifiedAt;
          if (last != null &&
              DateTime.now().millisecondsSinceEpoch - last < 24 * 3600 * 1000) {
            continue;
          }
          await LocNotificationService().show(
            id: r.id,
            title: '途径提醒',
            body: '你正在【${r.placeName}】附近 —— ${r.title}',
          );
          await (db.update(db.locationReminders)
                ..where((t) => t.id.equals(r.id)))
              .write(
            LocationRemindersCompanion(
              notifiedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }
      }
      await db.close();
    } catch (_) {
      return false;
    }
    return true;
  });
}

class LocationBgWorker {
  static const _uniqueName = 'location_reminder_periodic';

  static Future<void> init() async {
    await Workmanager().initialize(locationBgCallback, isInDebugMode: false);
  }

  static Future<void> start() async {
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      'check_location',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> stop() async {
    await Workmanager().cancelByUniqueName(_uniqueName);
  }
}
