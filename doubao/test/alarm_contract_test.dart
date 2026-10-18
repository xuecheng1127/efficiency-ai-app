// T13-BUGFIX 结构契约测试：确保 AlarmScheduler.kt 的 buildPendingIntent 里设了 action
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AlarmScheduler.buildPendingIntent 必须设置 action=ACTION_ALARM', () async {
    final file = File(
      'android/app/src/main/kotlin/com/efficiency/app/alarm/AlarmScheduler.kt',
    );
    expect(await file.exists(), true, reason: 'AlarmScheduler.kt 必须存在');
    final src = await file.readAsString();

    final hasActionInBuild = RegExp(
      r'fun buildPendingIntent[\s\S]*?action\s*=\s*AlarmReceiver\.ACTION_ALARM',
    ).hasMatch(src);
    expect(hasActionInBuild, true,
        reason: 'buildPendingIntent 必须设置 action=AlarmReceiver.ACTION_ALARM');

    final hasActionInCancel = RegExp(
      r'fun cancelTaskAlarm[\s\S]*?action\s*=\s*AlarmReceiver\.ACTION_ALARM',
    ).hasMatch(src);
    expect(hasActionInCancel, true,
        reason: 'cancelTaskAlarm 的 intent 也必须带 action');
  });

  test('AlarmReceiver.onReceive 必须有 else 兜底日志', () async {
    final file = File(
      'android/app/src/main/kotlin/com/efficiency/app/alarm/AlarmReceiver.kt',
    );
    expect(await file.exists(), true);
    final src = await file.readAsString();

    final hasElseFallback = RegExp(r'else\s*->\s*Log\.w').hasMatch(src);
    expect(hasElseFallback, true,
        reason: 'onReceive 的 when 必须有 else 兜底分支并记日志');
  });
}
