import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart'
    hide LocationReminder;
import 'package:efficiency_app/features/location/data/location_repository_impl.dart';
import 'package:efficiency_app/features/location/domain/location_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

/// 途径提醒：距离 / 围栏判定 / 24h 去重 / 仓库。
void main() {
  group('distanceMeters', () {
    test('同一点为 0', () {
      expect(distanceMeters(39.9, 116.4, 39.9, 116.4), 0);
    });

    test('纬度 1 度约 111km（误差 < 1%）', () {
      final d = distanceMeters(0, 0, 1, 0);
      expect(d, closeTo(111195, 1200));
    });

    test('北京到上海约 1067km（误差 < 2%）', () {
      final d = distanceMeters(39.9042, 116.4074, 31.2304, 121.4737);
      expect(d, closeTo(1067000, 22000));
    });
  });

  group('evaluate（进入 / 离开 / 去重）', () {
    final now = DateTime(2026, 10, 18, 12);
    LocationReminder reminder({
      TriggerOn on = TriggerOn.enter,
      bool enabled = true,
      DateTime? notifiedAt,
      int radius = 200,
      DateTime? deletedAt,
    }) => LocationReminder(
      id: 1,
      title: '买菜',
      placeName: '永辉超市',
      latitude: 39.9000,
      longitude: 116.4000,
      radiusMeters: radius,
      triggerOn: on,
      enabled: enabled,
      notifiedAt: notifiedAt,
      createdAt: now,
      deletedAt: deletedAt,
    );

    // 距目标点约 111m（纬度 +0.001）
    const insideLat = 39.9010;
    const outsideLat = 39.9100;

    test('进入：上次在外、这次在内 → 触发', () {
      final d = evaluate(
        reminder: reminder(),
        lat: insideLat,
        lon: 116.4,
        lastInside: false,
        now: now,
      );
      expect(d.inside, isTrue);
      expect(d.trigger, isNotNull);
      expect(d.trigger!.message, contains('到达'));
    });

    test('已经在内：不重复触发', () {
      final d = evaluate(
        reminder: reminder(),
        lat: insideLat,
        lon: 116.4,
        lastInside: true,
        now: now,
      );
      expect(d.trigger, isNull);
    });

    test('首次（lastInside=null）且已在围栏内 → 触发一次', () {
      final d = evaluate(
        reminder: reminder(),
        lat: insideLat,
        lon: 116.4,
        lastInside: null,
        now: now,
      );
      expect(d.trigger, isNotNull);
    });

    test('离开模式：上次在内、这次在外 → 触发；反之不触发', () {
      final leave = evaluate(
        reminder: reminder(on: TriggerOn.exit),
        lat: outsideLat,
        lon: 116.4,
        lastInside: true,
        now: now,
      );
      expect(leave.trigger, isNotNull);
      expect(leave.trigger!.message, contains('离开'));

      final stay = evaluate(
        reminder: reminder(on: TriggerOn.exit),
        lat: outsideLat,
        lon: 116.4,
        lastInside: false,
        now: now,
      );
      expect(stay.trigger, isNull);
    });

    test('24 小时内已提醒过 → 不再触发', () {
      final d = evaluate(
        reminder: reminder(
          notifiedAt: now.subtract(const Duration(hours: 23)),
        ),
        lat: insideLat,
        lon: 116.4,
        lastInside: false,
        now: now,
      );
      expect(d.trigger, isNull);

      final later = evaluate(
        reminder: reminder(
          notifiedAt: now.subtract(const Duration(hours: 25)),
        ),
        lat: insideLat,
        lon: 116.4,
        lastInside: false,
        now: now,
      );
      expect(later.trigger, isNotNull);
    });

    test('已关闭 / 已删除的提醒不触发', () {
      for (final r in [
        reminder(enabled: false),
        reminder(deletedAt: now),
      ]) {
        final d = evaluate(
          reminder: r,
          lat: insideLat,
          lon: 116.4,
          lastInside: false,
          now: now,
        );
        expect(d.trigger, isNull);
      }
    });

    test('半径边界：刚好在半径上算「在内」', () {
      // 111.19m 左右 → 用 150m 半径应判定在内
      final d = evaluate(
        reminder: reminder(radius: 150),
        lat: insideLat,
        lon: 116.4,
        lastInside: false,
        now: now,
      );
      expect(d.inside, isTrue);
    });
  });

  group('LocationRepositoryImpl（内存 SQLite）', () {
    late AppDatabase db;
    late LocationRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = LocationRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('标题为空或坐标越界不落库', () async {
      expect(
        await repo.create(title: '  ', placeName: 'x', latitude: 1, longitude: 1),
        isNull,
      );
      expect(
        await repo.create(
          title: '买菜',
          placeName: 'x',
          latitude: 95,
          longitude: 1,
        ),
        isNull,
      );
    });

    test('创建后能读到，默认 enable / enter / 200m', () async {
      final id = (await repo.create(
        title: '买菜',
        placeName: '永辉',
        latitude: 39.9,
        longitude: 116.4,
      ))!;
      final r = (await repo.watchAll().first).single;
      expect(r.id, id);
      expect(r.enabled, isTrue);
      expect(r.triggerOn, TriggerOn.enter);
      expect(r.radiusMeters, 200);
    });

    test('allEnabled 只返回启用项；setEnabled 能切换', () async {
      final a = (await repo.create(
        title: 'A',
        placeName: '',
        latitude: 1,
        longitude: 1,
      ))!;
      await repo.create(title: 'B', placeName: '', latitude: 2, longitude: 2);
      expect(await repo.allEnabled(), hasLength(2));

      await repo.setEnabled(a, false);
      final enabled = await repo.allEnabled();
      expect(enabled, hasLength(1));
      expect(enabled.single.title, 'B');
    });

    test('markNotified 写入时间（24h 去重依赖它）', () async {
      final id = (await repo.create(
        title: 'A',
        placeName: '',
        latitude: 1,
        longitude: 1,
      ))!;
      final at = DateTime(2026, 10, 18, 12);
      await repo.markNotified(id, at);
      final r = (await repo.watchAll().first).single;
      expect(r.notifiedAt, at);
    });

    test('软删除 + 撤销', () async {
      final id = (await repo.create(
        title: 'A',
        placeName: '',
        latitude: 1,
        longitude: 1,
      ))!;
      await repo.softDelete(id);
      expect(await repo.watchAll().first, isEmpty);
      await repo.restore(id);
      expect(await repo.watchAll().first, hasLength(1));
    });
  });
}
