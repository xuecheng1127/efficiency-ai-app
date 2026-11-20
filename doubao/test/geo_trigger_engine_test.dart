import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/features/toolbox/data/geo_trigger_engine.dart';

void main() {
  // 基准点：淮南某坐标
  const lat0 = 32.63;
  const lng0 = 117.98;

  GeoReminderInput reminder({
    int id = 1,
    String triggerOn = 'enter',
    double lat = lat0,
    double lng = lng0,
    int radius = 500,
  }) {
    return GeoReminderInput(
      id: id,
      title: '顺便买菜',
      placeName: '家附近超市',
      latitude: lat,
      longitude: lng,
      radiusMeters: radius,
      triggerOn: triggerOn,
    );
  }

  group('Haversine 距离', () {
    test('同一点距离为 0', () {
      expect(geoDistanceMeters(lat0, lng0, lat0, lng0), closeTo(0, 0.001));
    });

    test('纬度差 0.01 度约 1112 米', () {
      final d = geoDistanceMeters(lat0, lng0, lat0 + 0.01, lng0);
      expect(d, closeTo(1112, 20));
    });

    test('经度差 0.01 度在纬度 32.63 处约 936.5 米', () {
      final d = geoDistanceMeters(lat0, lng0, lat0, lng0 + 0.01);
      expect(d, closeTo(936.45, 10));
    });

    test('距离对称：A→B 等于 B→A', () {
      final a = geoDistanceMeters(lat0, lng0, 31.8, 116.5);
      final b = geoDistanceMeters(31.8, 116.5, lat0, lng0);
      expect(a, closeTo(b, 0.0001));
    });
  });

  group('isInside 半径判定', () {
    test('半径内判定为 inside', () {
      expect(isInside(reminder(), lat0, lng0), isTrue);
      expect(isInside(reminder(), lat0 + 0.001, lng0), isTrue); // ~111m
    });

    test('半径外判定为 outside', () {
      expect(isInside(reminder(), lat0 + 0.02, lng0), isFalse); // ~2.2km
    });    test('半径为 0 恒为 outside（防御）', () {
      expect(isInside(reminder(radius: 0), lat0, lng0), isFalse);
    });
  });

  group('进入模式状态翻转', () {
    test('首次采样已在半径内 → 发进入通知', () {
      final r = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0,
        longitude: lng0,
        reminders: [reminder()],
        lastInside: {},
      ));
      expect(r.notifications, hasLength(1));
      expect(r.notifications.first.kind, 'enter');
      expect(r.notifications.first.body, contains('家附近超市'));
      expect(r.insideStates[1], isTrue);
    });

    test('首次采样在半径外 → 不发通知，记录 outside', () {
      final r = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0 + 0.02,
        longitude: lng0,
        reminders: [reminder()],
        lastInside: {},
      ));
      expect(r.notifications, isEmpty);
      expect(r.insideStates[1], isFalse);
    });

    test('outside→inside 翻转发通知；inside 持续不再发', () {
      final first = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0 + 0.02,
        longitude: lng0,
        reminders: [reminder()],
        lastInside: {},
      ));
      expect(first.notifications, isEmpty);

      final second = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0,
        longitude: lng0,
        reminders: [reminder()],
        lastInside: first.insideStates,
      ));
      expect(second.notifications, hasLength(1));
      expect(second.notifications.first.kind, 'enter');

      final third = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0,
        longitude: lng0,
        reminders: [reminder()],
        lastInside: second.insideStates,
      ));
      expect(third.notifications, isEmpty); // 无翻转不再通知
    });

    test('inside→outside 对 enter 模式不通知（仅记录）', () {
      final r = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0 + 0.02,
        longitude: lng0,
        reminders: [reminder()],
        lastInside: {1: true},
      ));
      expect(r.notifications, isEmpty);
      expect(r.insideStates[1], isFalse);
    });
  });

  group('离开模式状态翻转', () {
    test('首次采样在半径内 → 不发通知（避免一启用就吵）', () {
      final r = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0,
        longitude: lng0,
        reminders: [reminder(triggerOn: 'exit')],
        lastInside: {},
      ));
      expect(r.notifications, isEmpty);
      expect(r.insideStates[1], isTrue);
    });

    test('inside→outside 翻转发离开通知', () {
      final r = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0 + 0.02,
        longitude: lng0,
        reminders: [reminder(triggerOn: 'exit')],
        lastInside: {1: true},
      ));
      expect(r.notifications, hasLength(1));
      expect(r.notifications.first.kind, 'exit');
      expect(r.notifications.first.body, contains('已离开'));
    });

    test('outside 持续对 exit 模式不通知', () {
      final r = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0 + 0.02,
        longitude: lng0,
        reminders: [reminder(triggerOn: 'exit')],
        lastInside: {1: false},
      ));
      expect(r.notifications, isEmpty);
    });
  });

  group('多提醒混合', () {
    test('一次轮询可同时命中多条，互不干扰', () {
      final rs = [
        reminder(id: 1, lat: lat0, lng: lng0),
        reminder(id: 2, lat: lat0 + 0.01, lng: lng0), // 1.1km 外
        reminder(id: 3, lat: lat0 - 0.0005, lng: lng0, triggerOn: 'exit'),
      ];
      // 先采样：1 在内、2 在外、3 在内（exit 模式首次不通知）
      final first = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0,
        longitude: lng0,
        reminders: rs,
        lastInside: {},
      ));
      expect(first.notifications, hasLength(1)); // 只有 id=1 enter
      expect(first.insideStates, {1: true, 2: false, 3: true});

      // 移动到 2 的位置：1 离开（enter 模式不通知）、2 进入（通知）、3 离开（exit 通知）
      final second = evaluateGeoCheck(GeoCheckInput(
        latitude: lat0 + 0.01,
        longitude: lng0,
        reminders: rs,
        lastInside: first.insideStates,
      ));
      final kinds = second.notifications.map((n) => n.reminderId).toSet();
      expect(kinds, {2, 3});
      expect(second.insideStates, {1: false, 2: true, 3: false});
    });

    test('提醒列表为空 → 无通知、状态为空', () {
      final r = evaluateGeoCheck(const GeoCheckInput(
        latitude: lat0,
        longitude: lng0,
        reminders: [],
      ));
      expect(r.notifications, isEmpty);
      expect(r.insideStates, isEmpty);
    });
  });

  group('服务通知文案', () {
    test('0/1/N 个地点文案', () {
      expect(serviceNotificationText(0), '0 个地点正在监测');
      expect(serviceNotificationText(1), '1 个地点正在监测');
      expect(serviceNotificationText(7), '7 个地点正在监测');
    });
  });
}
