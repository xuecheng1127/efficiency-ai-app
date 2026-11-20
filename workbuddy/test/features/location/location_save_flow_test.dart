import 'dart:async';

import 'package:efficiency_app/features/location/application/location_monitor.dart';
import 'package:efficiency_app/features/location/application/location_watcher.dart';
import 'package:efficiency_app/features/location/domain/location_reminder.dart';
import 'package:efficiency_app/features/location/domain/location_repository.dart';
import 'package:efficiency_app/features/location/presentation/location_edit_page.dart';
import 'package:efficiency_app/features/location/providers/location_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// R4B：**保存提醒绝不能卡住**（v1.6 的真实现场）。
///
/// 现场是：点「保存」→ 按钮变成「保存中…」→ 永远不结束 →
/// 但数据库里那条提醒其实已经写进去了（用户会以为没存上，再点一次就多一条）。
///
/// 根因有两条，这里各锁一个：
/// 1. 后台监测（`resumeByUserAction`）一旦抛异常/不返回，保存流程就跟着挂
///    → 现在它被挪到页面退出之后，且带超时；
/// 2. `_save()` 没有 finally 复位 `_saving` → 任何异常都会让按钮永久禁用。
void main() {
  late _FakeRepo repo;

  setUp(() => repo = _FakeRepo());

  Future<_FakeMonitor> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final watcher = LocationWatcher(repo);
    final monitor = _FakeMonitor(repo, watcher);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationRepositoryProvider.overrideWithValue(repo),
          locationMonitorProvider.overrideWithValue(monitor),
        ],
        child: const MaterialApp(home: _Launcher()),
      ),
    );
    await tester.tap(find.text('打开添加页'));
    await tester.pumpAndSettle();
    return monitor;
  }

  Future<void> fillValidForm(WidgetTester tester, {String title = '买菜'}) async {
    await tester.enterText(find.byType(TextField).at(0), title);
    await tester.tap(find.text('手输坐标'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '39.908722');
    await tester.enterText(find.byType(TextField).at(3), '116.397499');
    await tester.pump();
  }

  testWidgets('保存立即返回：不等后台服务启动，页面直接退出', (tester) async {
    final monitor = await pumpEditor(tester);
    await fillValidForm(tester);

    await tester.tap(find.text('保存提醒'));
    await tester.pump(); // 起头
    await tester.pump(const Duration(milliseconds: 200));
    // 200ms 时已经 pop（不等后台服务），再给退场动画留一点时间
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('保存中…'), findsNothing, reason: '不能停在保存中');
    expect(find.byType(LocationEditPage), findsNothing, reason: '应该已经退出页面');
    expect(repo.createCalls, 1);
    expect(find.text('已添加：买菜'), findsOneWidget);

    // 后台监测还在跑（假 monitor 故意慢 3 秒）：保存不该被它拖住
    expect(monitor.resumeCalls, 1);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('写库抛异常：按钮复位、给出错误、页面不退出', (tester) async {
    repo.createError = StateError('disk I/O error');
    await pumpEditor(tester);
    await fillValidForm(tester);

    await tester.tap(find.text('保存提醒'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('保存中…'), findsNothing);
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(find.byType(LocationEditPage), findsOneWidget);

    // 还能再点一次（不是永久禁用）
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('保存提醒'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('写库返回 null：提示检查坐标，页面不退出', (tester) async {
    repo.nextId = null;
    await pumpEditor(tester);
    await fillValidForm(tester);

    await tester.tap(find.text('保存提醒'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('保存中…'), findsNothing);
    expect(find.textContaining('检查一下坐标范围'), findsOneWidget);
    expect(find.byType(LocationEditPage), findsOneWidget);
  });

  testWidgets('没填内容直接保存：不发请求、给出提示', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('保存提醒'));
    await tester.pump();

    expect(repo.createCalls, 0);
    expect(find.textContaining('写一句提醒内容'), findsOneWidget);
  });
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LocationEditPage()),
        ),
        child: const Text('打开添加页'),
      ),
    ),
  );
}

class _FakeRepo implements LocationRepository {
  Object? createError;
  int? nextId = 1;
  int createCalls = 0;
  final _all = StreamController<List<LocationReminder>>.broadcast();

  @override
  Future<int?> create({
    required String title,
    required String placeName,
    required double latitude,
    required double longitude,
    int radiusMeters = 200,
    TriggerOn triggerOn = TriggerOn.enter,
    bool enabled = true,
  }) async {
    createCalls++;
    if (createError != null) throw createError!;
    return nextId;
  }

  @override
  Future<List<LocationReminder>> allEnabled() async => const [];

  @override
  Stream<List<LocationReminder>> watchAll() => _all.stream;

  @override
  Future<void> setEnabled(int id, bool enabled) async {}

  @override
  Future<void> markNotified(int id, DateTime at) async {}

  @override
  Future<void> softDelete(int id) async {}

  @override
  Future<void> restore(int id) async {}
}

/// 故意「永远起不来」的后台监测：用来证明保存不依赖它。
class _FakeMonitor extends LocationMonitor {
  // LocationMonitor 的构造参数是私有的（`this._repo`），无法用 super 形参转发
  // ignore: use_super_parameters
  _FakeMonitor(LocationRepository repo, LocationWatcher watcher)
    : super(repo, watcher);

  int resumeCalls = 0;

  @override
  Future<ServiceNudge> resumeByUserAction() async {
    resumeCalls++;
    await Future<void>.delayed(const Duration(seconds: 3));
    return const ServiceNudge(ok: false, error: 'test: service unavailable');
  }
}
