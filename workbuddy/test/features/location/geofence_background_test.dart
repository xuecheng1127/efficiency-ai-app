import 'package:efficiency_app/features/location/data/reminder_snapshot.dart';
import 'package:efficiency_app/features/location/domain/geofence_pulse.dart';
import 'package:efficiency_app/features/location/domain/location_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

/// R4：后台触发链路里**不依赖插件**的那部分。
///
/// 为什么单测要死盯这一层：真正的后台 isolate 在模拟器上只能靠「等 60 秒」
/// 验证一次，反馈极慢；而「状态翻转 / 24h 去重 / 从 SQLite 行还原实体」
/// 这三件事才是会静默出错的（错了不会崩，只是永远不提醒）。
void main() {
  LocationReminder reminder({
    int id = 1,
    TriggerOn on = TriggerOn.enter,
    bool enabled = true,
    DateTime? notifiedAt,
    int radius = 500,
    DateTime? deletedAt,
  }) => LocationReminder(
    id: id,
    title: '买菜',
    placeName: '永辉超市',
    latitude: 39.9000,
    longitude: 116.4000,
    radiusMeters: radius,
    triggerOn: on,
    enabled: enabled,
    notifiedAt: notifiedAt,
    createdAt: DateTime(2026, 11, 20, 1),
    deletedAt: deletedAt,
  );

  // 纬度 +0.001 ≈ 111m（远在 500m 半径内）；+0.02 ≈ 2.2km（远在外面）
  const insideLat = 39.9010;
  const outsideLat = 39.9200;
  const lon = 116.4;
  final now = DateTime(2026, 11, 20, 1, 45);

  group('runPulse：进入 / 离开 / 去重', () {
    test('进入：上次在外 + 这次在内 + 从没提醒过 → 发一条', () {
      final result = runPulse(
        reminders: [reminder()],
        latitude: insideLat,
        longitude: lon,
        lastInside: {1: false},
        lastNotified: const {},
        now: now,
      );
      expect(result.alerts, hasLength(1));
      expect(result.alerts.single.message, contains('到达'));
      expect(result.insideById[1], isTrue);
    });

    test('状态没翻转 → 不发；但 inside 仍然要回写', () {
      final result = runPulse(
        reminders: [reminder()],
        latitude: insideLat,
        longitude: lon,
        lastInside: {1: true},
        lastNotified: const {},
        now: now,
      );
      expect(result.isEmpty, isTrue);
      expect(result.insideById[1], isTrue);
    });

    test('首次（没有历史状态）且已在围栏内 → 提醒一次', () {
      final result = runPulse(
        reminders: [reminder()],
        latitude: insideLat,
        longitude: lon,
        lastInside: const {},
        lastNotified: const {},
        now: now,
      );
      expect(result.alerts, hasLength(1));
    });

    test('离开模式：上次在内 → 走出半径才发；一直在内不发', () {
      final left = runPulse(
        reminders: [reminder(on: TriggerOn.exit)],
        latitude: outsideLat,
        longitude: lon,
        lastInside: {1: true},
        lastNotified: const {},
        now: now,
      );
      expect(left.alerts.single.message, contains('离开'));
      expect(left.insideById[1], isFalse);

      final stillIn = runPulse(
        reminders: [reminder(on: TriggerOn.exit)],
        latitude: insideLat,
        longitude: lon,
        lastInside: {1: true},
        lastNotified: const {},
        now: now,
      );
      expect(stillIn.isEmpty, isTrue);
    });

    test('缓存里的「上次提醒」比数据库新 → 24h 去重按缓存算', () {
      // 数据库还停在 2 天前（后台没写库），缓存是 1 小时前（后台写的）
      final result = runPulse(
        reminders: [
          reminder(notifiedAt: now.subtract(const Duration(days: 2))),
        ],
        latitude: insideLat,
        longitude: lon,
        lastInside: {1: false},
        lastNotified: {1: now.subtract(const Duration(hours: 1))},
        now: now,
      );
      expect(result.isEmpty, isTrue, reason: '1 小时前刚提醒过，不该再来一条');

      // 缓存超过 24h → 允许
      final later = runPulse(
        reminders: [reminder()],
        latitude: insideLat,
        longitude: lon,
        lastInside: {1: false},
        lastNotified: {1: now.subtract(const Duration(hours: 25))},
        now: now,
      );
      expect(later.alerts, hasLength(1));
    });

    test('关闭 / 已删除的围栏：不发，也不进 inside 表', () {
      final result = runPulse(
        reminders: [
          reminder(id: 1, enabled: false),
          reminder(id: 2, deletedAt: now),
        ],
        latitude: insideLat,
        longitude: lon,
        lastInside: const {},
        lastNotified: const {},
        now: now,
      );
      expect(result.isEmpty, isTrue);
    });

    test('多条围栏各算各的，互不串味', () {
      final result = runPulse(
        reminders: [
          reminder(id: 1),
          reminder(id: 2, on: TriggerOn.exit),
          reminder(id: 3),
        ],
        latitude: insideLat,
        longitude: lon,
        lastInside: {1: false, 2: true, 3: true},
        lastNotified: const {},
        now: now,
      );
      // 1 进入触发；2 仍在内不触发；3 已在内不触发
      expect(result.alerts.map((a) => a.reminderId), [1]);
      expect(result.insideById, {1: true, 2: true, 3: true});
    });
  });

  group('latestOf', () {
    test('取更晚的那个；null 让位', () {
      final older = DateTime(2026, 1, 1);
      final newer = DateTime(2026, 1, 2);
      expect(latestOf(null, null), isNull);
      expect(latestOf(older, null), older);
      expect(latestOf(null, newer), newer);
      expect(latestOf(newer, older), newer);
      expect(latestOf(older, newer), newer);
    });
  });

  group('LocationAlert 跨 isolate 传输', () {
    test('toJson → tryParse 不丢字段', () {
      const alert = LocationAlert(
        reminderId: 7,
        title: '买菜',
        placeName: '永辉',
        message: '你已到达 永辉',
        distanceMeters: 123.4,
      );
      final back = LocationAlert.tryParse(alert.toJson())!;
      expect(back.reminderId, 7);
      expect(back.title, '买菜');
      expect(back.message, '你已到达 永辉');
      expect(back.distanceMeters, 123.4);
    });

    test('不是围栏数据 / 缺 id → null（同一条通道将来还要跑别的任务）', () {
      expect(LocationAlert.tryParse('hello'), isNull);
      expect(LocationAlert.tryParse({'kind': 'other', 'id': 1}), isNull);
      expect(LocationAlert.tryParse({'kind': 'geofence'}), isNull);
    });
  });

  group('ReminderSnapshot.parseRows（后台直读 SQLite 的还原）', () {
    Map<String, Object?> row({
      Object? id = 3,
      Object? enabled = 1,
      Object? radius = 500,
      Object? notified,
    }) => {
      'id': id,
      'title': '买菜',
      'place_name': '永辉超市',
      'latitude': 39.9,
      'longitude': 116.4,
      'radius_meters': radius,
      'trigger_on': 'enter',
      'enabled': enabled,
      'notified_at': notified,
      'created_at': 1763571600, // 2025-11-19 21:00 UTC 左右
      'deleted_at': null,
    };

    test('SQLite 原生 0/1 与 drift 的 bool 都要认', () {
      expect(ReminderSnapshot.parseRows([row(enabled: 1)]).single.enabled, isTrue);
      expect(
        ReminderSnapshot.parseRows([row(enabled: 0)]).single.enabled,
        isFalse,
      );
      expect(
        ReminderSnapshot.parseRows([row(enabled: true)]).single.enabled,
        isTrue,
      );
    });

    test('时间列按 Unix 秒还原（drift 默认），字符串时间也兼容', () {
      final fromSeconds = ReminderSnapshot.parseRows([
        row(notified: 1763571600),
      ]).single;
      expect(
        fromSeconds.notifiedAt!.toUtc().millisecondsSinceEpoch ~/ 1000,
        1763571600,
      );

      final fromIso = ReminderSnapshot.parseRows([
        row(notified: '2026-11-20T01:30:00.000'),
      ]).single;
      expect(fromIso.notifiedAt, isNotNull);
    });

    test('半径被夹到下限 50m（防止误差半径 0 导致永不触发）', () {
      expect(
        ReminderSnapshot.parseRows([row(radius: 10)]).single.radiusMeters,
        50,
      );
      expect(
        ReminderSnapshot.parseRows([row(radius: 500)]).single.radiusMeters,
        500,
      );
    });

    test('残缺行（缺 id / 缺坐标）直接跳过，不整批失败', () {
      final rows = [
        row(),
        {...row(), 'id': null},
        {...row(), 'latitude': null},
        {...row(), 'longitude': 'not-a-number'},
      ];
      expect(ReminderSnapshot.parseRows(rows), hasLength(1));
    });

    test('trigger_on 为空按「进入」处理（老库补列的情况）', () {
      final r = ReminderSnapshot.parseRows([
        {...row(), 'trigger_on': null},
      ]).single;
      expect(r.triggerOn, TriggerOn.enter);
    });
  });
}
