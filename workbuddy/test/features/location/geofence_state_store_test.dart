import 'dart:convert';
import 'dart:io';

import 'package:efficiency_app/features/location/data/geofence_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// R4B：围栏状态从 SharedPreferences 换成 JSON 文件后，必须守住的三件事。
///
/// 为什么这一层要单测：它是**两个 isolate 之间唯一的共享内存**。
/// 坏了不会崩，只会「永远不提醒」或者「每次都在提醒」，只能在真机上
/// 等 60 秒才发现 —— 反馈极慢。
void main() {
  late Directory dir;

  File stateFile() => File(p.join(dir.path, 'geofence_state.json'));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('geofence_state_');
    GeofenceStateStore.resetMemoryShadow();
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('跨实例可见：A 写的东西，B（另一个 isolate 的替身）读得到', () async {
    final writer = GeofenceStateStore(file: stateFile());
    final notifiedAt = DateTime.fromMillisecondsSinceEpoch(1700000000123);
    await writer.saveInside({7: true});
    await writer.saveNotified(7, notifiedAt);
    await writer.saveLastPulse(notifiedAt);

    // 模拟「另一个 isolate」：清掉影子缓存，只靠文件
    GeofenceStateStore.resetMemoryShadow();
    final reader = GeofenceStateStore(file: stateFile());
    final snapshot = await reader.load();

    expect(snapshot.inside[7], isTrue);
    expect(snapshot.notified[7]!.millisecondsSinceEpoch, 1700000000123);
    expect(snapshot.lastPulseAt!.millisecondsSinceEpoch, 1700000000123);
  });

  test('值没变就不写盘（每分钟一拍，不能反复落盘）', () async {
    final store = GeofenceStateStore(file: stateFile());
    await store.saveInside({1: true});
    final before = stateFile().readAsStringSync();

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await store.saveInside({1: true});

    expect(stateFile().readAsStringSync(), before);
  });

  test('值变了会写盘，且另一个实例能看到新值', () async {
    final store = GeofenceStateStore(file: stateFile());
    await store.saveInside({1: true});
    await store.saveInside({1: false});

    GeofenceStateStore.resetMemoryShadow();
    expect((await GeofenceStateStore(file: stateFile()).load()).inside[1], isFalse);
  });

  test('文件是坏 JSON：load 不抛，下一次写入把文件修好', () async {
    stateFile().writeAsStringSync('{"inside": {"1": tru');

    final store = GeofenceStateStore(file: stateFile());
    final broken = await store.load();
    expect(broken.inside, isEmpty);
    expect(broken.paused, isFalse);

    await store.setPaused(true);
    final decoded = jsonDecode(stateFile().readAsStringSync()) as Map;
    expect(decoded['paused'], isTrue);
  });

  test('文件不存在（首次运行）也不抛', () async {
    final store = GeofenceStateStore(file: stateFile());
    expect(await store.isPaused(), isFalse);
    expect((await store.load()).inside, isEmpty);
    expect(stateFile().existsSync(), isFalse, reason: '只读不该创建文件');
  });

  test('暂停标记能落盘并被新实例读到', () async {
    await GeofenceStateStore(file: stateFile()).setPaused(true);
    GeofenceStateStore.resetMemoryShadow();
    expect(await GeofenceStateStore(file: stateFile()).isPaused(), isTrue);

    await GeofenceStateStore(file: stateFile()).setPaused(false);
    GeofenceStateStore.resetMemoryShadow();
    expect(await GeofenceStateStore(file: stateFile()).isPaused(), isFalse);
  });

  test('连续写多个键不会互相覆盖（读-改-写是合并的）', () async {
    final store = GeofenceStateStore(file: stateFile());
    await Future.wait([
      store.saveInside({1: true}),
      store.saveNotified(1, DateTime.fromMillisecondsSinceEpoch(1000)),
      store.setPaused(true),
    ]);

    GeofenceStateStore.resetMemoryShadow();
    final snapshot = await GeofenceStateStore(file: stateFile()).load();
    expect(snapshot.inside[1], isTrue);
    expect(snapshot.notified[1]!.millisecondsSinceEpoch, 1000);
    expect(snapshot.paused, isTrue);
  });
}
