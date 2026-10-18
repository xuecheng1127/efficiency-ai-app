import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

import '../../../core/database/app_database.dart';
import 'location_reminder_repository.dart';

/// 途径提醒前台轮询监控
/// app 在前台时每 30 秒取一次位置，对启用中的提醒做距离判断
class LocationReminderMonitor {
  final LocationReminderRepository repo;
  final Location location;
  LocationReminderMonitor(this.repo) : location = Location();

  Timer? _timer;
  StreamSubscription<LocationData>? _locSub;

  /// 触发回调（用于 SnackBar）
  void Function(LocationReminderRow r, double distanceMeters)? onTrigger;

  Future<void> start() async {
    var perm = await location.hasPermission();
    if (perm == PermissionStatus.denied) {
      perm = await location.requestPermission();
    }
    if (perm != PermissionStatus.granted) return;

    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final pos = await location.getLocation();
      if (pos.latitude == null || pos.longitude == null) return;
      final items = await (db.select(db.locationReminders)
            ..where((t) => t.enabled.equals(1) & t.deletedAt.isNull()))
          .get();
      for (final r in items) {
        if (!await repo.shouldNotify(r)) continue;
        final d = LocationReminderRepository.distanceMeters(
          pos.latitude!, pos.longitude!, r.latitude, r.longitude,
        );
        if (d <= r.radiusMeters) {
          await repo.markNotified(r.id);
          onTrigger?.call(r, d);
        }
      }
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _locSub?.cancel();
  }

  AppDatabase get db => AppDatabase.instance;
}
