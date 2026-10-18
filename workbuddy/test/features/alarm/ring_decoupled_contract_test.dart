import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// T13b · 响铃生命周期与页面解耦 —— **结构契约测试**。
///
/// ## 这个文件测的是什么（不夸大）
///
/// `AlarmService` / `AlarmFullScreenActivity` 是 Kotlin，跑在 Android 的服务与窗口体系里。
/// `flutter test` 是 Dart VM 测试，**执行不了它们**。所以这里断言的是**结构契约**：
///
/// 1. 响铃归属是否真的从 Activity 迁到了服务（`MediaPlayer` 在服务侧、不在 Activity 侧）；
/// 2. 那个**致命回归点**是否被守住：**Activity 的 `onDestroy` 不得再停铃**；
/// 3. 「停铃必撤通知」「动作打到服务」「AUTO_STOP 挂在服务上」这三条是否有落点；
/// 4. manifest 的 `foregroundServiceType` / 权限是否声明齐。
///
/// 这些是**回归防护**：一旦有人把 `MediaPlayer` 挪回 Activity、在 Activity 的
/// `onDestroy` 里加回 `stopRingtone()`、或把 AUTO_STOP 挪回页面，测试立刻红 ——
/// 而那正是真机实测中「铃只响 211 毫秒」的成因。
///
/// **行为验证（熄屏锁屏下铃持续 ≥30 秒、页面销毁后仍在响）属真机验收**，本文件不冒充它。
void main() {
  final androidRoot = p.join('android', 'app', 'src', 'main');
  final kotlinRoot =
      p.join(androidRoot, 'kotlin', 'com', 'efficiency', 'app', 'efficiency_app', 'alarm');

  final manifest = File(p.join(androidRoot, 'AndroidManifest.xml')).readAsStringSync();
  final contract = File(p.join(kotlinRoot, 'AlarmContract.kt')).readAsStringSync();
  final service = File(p.join(kotlinRoot, 'AlarmService.kt')).readAsStringSync();
  final activity = File(p.join(kotlinRoot, 'AlarmFullScreenActivity.kt')).readAsStringSync();
  final receiver = File(p.join(kotlinRoot, 'AlarmReceiver.kt')).readAsStringSync();
  final notifications = File(p.join(kotlinRoot, 'AlarmNotifications.kt')).readAsStringSync();

  // 只对**代码**断言：KDoc 里天然会写「以前 MediaPlayer 挂在本页上」「不再发给 AlarmReceiver」
  // 这类说明，拿带注释的原文做 isNot(contains(...)) 会全部误判。
  final contractCode = _stripComments(contract);
  final serviceCode = _stripComments(service);
  final activityCode = _stripComments(activity);
  final receiverCode = _stripComments(receiver);
  final notificationsCode = _stripComments(notifications);

  group('T13b 响铃解耦（结构契约）', () {
    test('C1: manifest 声明 AlarmService 为 specialUse 前台服务，并给出 Play 用途说明', () {
      final block = _serviceBlock(manifest, 'AlarmService');
      expect(block, contains('android:foregroundServiceType="specialUse"'), reason: 'R5/T17');
      expect(block, contains('android:exported="false"'));
      expect(
        block,
        contains('android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE'),
        reason: 'specialUse 必须声明子类型说明，否则上架 Play 会被打回',
      );
    });

    test('C2: manifest 声明两条前台服务权限', () {
      expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
      expect(manifest, contains('android.permission.FOREGROUND_SERVICE_SPECIAL_USE'));
    });

    test('C3: 响铃归属已迁出 Activity —— MediaPlayer/振动只在服务侧', () {
      expect(
        activityCode,
        isNot(contains('MediaPlayer')),
        reason: 'Activity 再持有 MediaPlayer 就等于回到「页面死 = 铃死」的老缺陷',
      );
      expect(activityCode, isNot(contains('Vibrator')));
      expect(activityCode, isNot(contains('AUTO_STOP')), reason: '超时兜底也不许挂在页面上');

      expect(serviceCode, contains('MediaPlayer'), reason: '服务必须是响铃归属者');
      expect(serviceCode, contains('isLooping = true'));
      expect(serviceCode, contains('USAGE_ALARM'), reason: '必须走闹钟音量流');
      expect(serviceCode, contains('CONTENT_TYPE_SONIFICATION'));
      expect(serviceCode, contains('Vibrator'), reason: '振动同样不能挂在页面上');
    });

    test('C4: AUTO_STOP 由服务持有，默认 5 分钟（R2）', () {
      expect(
        contractCode.replaceAll(' ', ''),
        contains('AUTO_STOP_MILLIS=5*60_000L'),
        reason: '规格写的是 5 分钟，改小/改大都要先改规格',
      );
      expect(serviceCode, contains('AlarmContract.AUTO_STOP_MILLIS'));
      expect(serviceCode, contains('AUTO_STOP fired'), reason: '超时要留下可 grep 的日志');
    });

    test('C5: Activity 只转发意图，不自己停铃', () {
      expect(activityCode, contains('AlarmService.sendControl'), reason: '按钮/息屏都要转发给服务');
      expect(activityCode, isNot(contains('finishAlarm')));
      expect(activityCode, isNot(contains('stopRingtone')));
      expect(activityCode, isNot(contains('stopRing')));
    });

    test('C6: ★致命回归点★ Activity 的 onDestroy/onStop 不得停铃', () {
      // 这就是「铃只响 211 毫秒」的成因：ROM 收掉页面 -> onDestroy -> stopRing()。
      for (final method in const ['onDestroy', 'onStop', 'onPause']) {
        final body = _methodBody(activityCode, 'override fun $method(');
        expect(
          body,
          isNot(contains('stopRing')),
          reason: '$method 里出现停铃调用 = 页面生命周期又绑上了响铃',
        );
      }
      // 反过来：服务的 onDestroy 才是允许收尾的地方
      expect(
        _methodBody(serviceCode, 'override fun onDestroy('),
        contains('stopRingtone'),
      );
    });

    test('C7: 通知的「贪睡/关闭」直接打到 AlarmService（不再绕回广播）', () {
      expect(notificationsCode, contains('PendingIntent.getService'));
      expect(notificationsCode, contains('AlarmService.controlIntent'));
      expect(
        notificationsCode,
        isNot(contains('AlarmReceiver')),
        reason: '动作不该再经过广播接收者——停铃的唯一归属者是服务',
      );
    });

    test('C8: R4 —— 全屏 Intent 路径未被破坏，且全程无 startActivity', () {
      expect(notificationsCode, contains('setFullScreenIntent'));
      expect(notificationsCode, contains('CATEGORY_ALARM'));
      expect(notificationsCode, contains('AlarmContract.NOTIFICATION_CHANNEL_ID'));
      for (final code in [activityCode, serviceCode, notificationsCode, receiverCode]) {
        expect(code, isNot(contains('startActivity')));
      }
    });

    test('C9: 停铃必撤通知（不留 ONGOING 僵尸通知）', () {
      final body = _methodBody(serviceCode, 'private fun finishRing(');
      expect(body, contains('AlarmNotifications.cancel'), reason: 'R3：停铃与撤通知是一件事');
      expect(
        serviceCode,
        contains('STOP_FOREGROUND_REMOVE'),
        reason: '前台状态与通知要一起摘掉（双保险）',
      );
    });

    test('C10: AlarmReceiver 只把响铃交给服务，自己不持有播放器', () {
      expect(receiverCode, contains('AlarmService.startRing'));
      expect(receiverCode, isNot(contains('MediaPlayer')));
    });

    test('C11: 服务留下「存活」证据（验收 #3/#4 靠它）', () {
      expect(serviceCode, contains('ALIVE tick='), reason: '心跳是「页面没了还在响」的可 grep 证据');
      expect(serviceCode, contains('HEARTBEAT_MILLIS'));
    });

    test('C12: 前台服务用 ServiceCompat 且显式传 specialUse 类型', () {
      expect(serviceCode, contains('ServiceCompat.startForeground'));
      expect(serviceCode, contains('FOREGROUND_SERVICE_TYPE_SPECIAL_USE'));
    });
  });
}

/// 从 manifest 里切出指定 service 的那一段。
///
/// 按 `android:name="...类名"` 这个**属性**匹配，不按元素名切——文件里注释也会提到类名。
String _serviceBlock(String manifest, String className) {
  final pattern = RegExp(
    '<service[^>]*android:name="[^"]*$className"[^>]*>[\\s\\S]*?</service>',
  );
  final match = pattern.firstMatch(manifest);
  if (match == null) {
    fail('AndroidManifest.xml 里找不到 service $className');
  }
  return match.group(0)!;
}

/// 取出某个成员的正文：从签名开始，到下一个 4 空格缩进的成员标记为止。
///
/// 嵌套层级更深的代码缩进 >4 空格，不会误判为成员边界。
String _methodBody(String code, String signature) {
  final start = code.indexOf(signature);
  if (start < 0) {
    fail('源码里找不到 `$signature`');
  }
  final tail = code.substring(start + signature.length);
  final markers = <RegExp>[
    RegExp(r'\n    override fun '),
    RegExp(r'\n    private fun '),
    RegExp(r'\n    internal fun '),
    RegExp(r'\n    fun '),
    RegExp(r'\n    companion object'),
    RegExp(r'\n    // -+'),
  ];
  var end = tail.length;
  for (final re in markers) {
    final m = re.firstMatch(tail);
    if (m != null && m.start < end) {
      end = m.start;
    }
  }
  return tail.substring(0, end);
}

/// 去掉 Kotlin 的块注释与行注释，只留可执行代码。
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');
