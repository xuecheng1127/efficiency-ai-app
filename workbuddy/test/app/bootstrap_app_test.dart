import 'package:efficiency_app/app/bootstrap_app.dart';
import 'package:efficiency_app/core/database/app_boot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// HARDENING A4 的界面层：启动失败必须有「错误态 + 恢复入口」，
/// 而不是停在 Flutter logo 的白屏上。
/// 模拟 drift 抛出来的原文（`SqliteException(26): …`）。
class _FakeSqliteError {
  @override
  String toString() =>
      'SqliteException(26): while selecting from statement, file is not a database, '
      'SQL logic error (code 26)';
}

void main() {
  /// 手机尺寸画布：默认的 800×600 装不下错误页的两个按钮，
  /// 按钮会落在视口外，`tester.tap` 点不到（这不是产品问题，是测试视口问题）。
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('启动失败：显示可读原因 + 重试 / 重建两个入口', (tester) async {
    usePhoneViewport(tester);
    var boots = 0;

    await tester.pumpWidget(
      BootstrapApp(
        boot: () async {
          boots++;
          throw _FakeSqliteError();
        },
        quarantine: () async => null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地数据打不开'), findsOneWidget);
    expect(find.text('重新尝试'), findsOneWidget);
    expect(find.text('备份数据库并重建'), findsOneWidget);
    // 错误原文要露出来（可复制），且不能是「SqliteException(26): …」这种原样堆砌
    expect(find.textContaining('file is not a database'), findsOneWidget);
    expect(find.textContaining('SQLite 错误码 26'), findsOneWidget);
    expect(boots, 1);
  });

  testWidgets('点“重新尝试”会重新跑一遍启动流程', (tester) async {
    usePhoneViewport(tester);
    var boots = 0;
    await tester.pumpWidget(
      BootstrapApp(
        boot: () async {
          boots++;
          throw StateError('still broken');
        },
        quarantine: () async => null,
      ),
    );
    await tester.pumpAndSettle();
    expect(boots, 1);

    await tester.tap(find.text('重新尝试'));
    await tester.pumpAndSettle();

    expect(boots, 2);
    // 仍然失败 → 仍然停在错误页，不闪退、不白屏
    expect(find.text('本地数据打不开'), findsOneWidget);
  });

  testWidgets('“备份并重建”：确认后先备份、再重试；取消则什么都不做', (tester) async {
    usePhoneViewport(tester);
    var boots = 0;
    var quarantined = 0;

    await tester.pumpWidget(
      BootstrapApp(
        boot: () async {
          boots++;
          throw StateError('boom');
        },
        quarantine: () async {
          quarantined++;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    // 1) 先取消：不备份、不重试
    await tester.tap(find.text('备份数据库并重建'));
    await tester.pumpAndSettle();
    expect(find.text('备份并重建'), findsOneWidget, reason: '必须先确认，不能一键清库');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(quarantined, 0);
    expect(boots, 1);

    // 2) 再确认：备份 1 次 + 重试 1 次
    await tester.tap(find.text('备份数据库并重建'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('备份并重建'));
    await tester.pumpAndSettle();

    expect(quarantined, 1);
    expect(boots, 2);
  });

  testWidgets('打开中不是白屏：有进度条和说明文字', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(
      BootstrapApp(
        boot: () => Future<BootResult>.delayed(
          const Duration(seconds: 5),
          () => throw StateError('never'),
        ),
        quarantine: () async => null,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在打开本地数据…'), findsOneWidget);

    // 收尾：让挂起的 Future 结束，避免测试结束时留下未完成的定时器
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
