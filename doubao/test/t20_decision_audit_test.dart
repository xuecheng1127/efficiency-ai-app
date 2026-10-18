import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// T20：定案落地校验机制
/// 检查 6 条已定案是否在代码中落地
void main() {
  test('1. AlarmReceiver 不出现裸 startActivity', () {
    final f = File('android/app/src/main/kotlin/com/efficiency/app/alarm/AlarmReceiver.kt');
    if (!f.existsSync()) return;
    final content = f.readAsStringSync();
    // 允许 Intent 构造，不允许直接 startActivity
    expect(content.contains('startActivity('), isFalse,
        reason: '禁止裸 startActivity 拉全屏');
  });

  test('2. 不出现 KEYCODE_POWER 拦截', () {
    final dir = Directory('android/app/src/main/kotlin/com/efficiency/app');
    final files = dir.listSync(recursive: true).whereType<File>();
    for (final f in files) {
      final c = f.readAsStringSync();
      expect(c.contains('KEYCODE_POWER'), isFalse,
          reason: '${f.path} 不应拦截 KEYCODE_POWER');
    }
  });

  test('3. AlarmService 读 DB 取参数', () {
    final f = File('android/app/src/main/kotlin/com/efficiency/app/alarm/AlarmService.kt');
    expect(f.existsSync(), isTrue);
    final c = f.readAsStringSync();
    expect(c.contains('sqlite') || c.contains('db') || c.contains('ScheduledAlarms'), isTrue,
        reason: 'AlarmService 应从 DB 读 ringtone/volume');
  });

  test('4. settings_page 引用 canScheduleExactAlarms', () {
    final f = File('lib/features/settings/presentation/settings_page.dart');
    expect(f.existsSync(), isTrue);
    final c = f.readAsStringSync();
    expect(c.contains('canScheduleExactAlarms'), isTrue,
        reason: '设置页应如实告知档位');
  });

  test('5. Manifest 声明 foregroundServiceType', () {
    final f = File('android/app/src/main/AndroidManifest.xml');
    expect(f.existsSync(), isTrue);
    final c = f.readAsStringSync();
    expect(c.contains('foregroundServiceType'), isTrue,
        reason: 'FGS 必须声明 foregroundServiceType');
  });

  test('6. AlarmService 不依赖 Activity 生命周期（T13b）', () {
    final f = File('android/app/src/main/kotlin/com/efficiency/app/alarm/AlarmService.kt');
    expect(f.existsSync(), isTrue);
    final c = f.readAsStringSync();
    // 1) 没有 Activity 生命周期回调
    expect(c.contains('onResume(') || c.contains('onPause('), isFalse,
        reason: 'Service 不应有 Activity 生命周期回调');
    // 2) 没有「Activity 是否存活」的判断
    expect(c.contains('isFinishing') || c.contains('isDestroyed'), isFalse,
        reason: 'Service 不应判断 Activity 存活');
    // 3) 没有 registerForActivityResult
    expect(c.contains('registerForActivityResult'), isFalse,
        reason: 'Service 不应有 ActivityResultLauncher');
    // 4) 响铃的核心持有者是 service：MediaPlayer 在 AlarmService 里
    expect(c.contains('MediaPlayer'), isTrue,
        reason: 'MediaPlayer 应在 AlarmService 中创建');
  });
}
