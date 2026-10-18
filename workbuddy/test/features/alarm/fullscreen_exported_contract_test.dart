import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// T14 · 全屏响铃页 `exported="false" -> "true"` + **来源校验** —— 结构契约测试。
///
/// ## 这个文件测的是什么（不夸大）
///
/// `AlarmFullScreenActivity` 是 Kotlin，跑在 Android 的窗口 / 锁屏体系里。
/// `flutter test` 是 Dart VM 测试，**执行不了它**。所以这里断言的是**结构契约**：
///
/// 1. Manifest 里该 Activity 的 `exported` 是否真的改成了 `true`；
/// 2. 那道来源校验的**存在性、语义（白名单而非黑名单）、位置（副作用之前）**；
/// 3. 生命周期日志是否补齐（9b 定性就靠它）。
///
/// 这些是**回归防护**：一旦有人把 `exported` 改回 `false`（9b 的故障形态）、
/// 把来源校验删掉（`exported=true` 之后裸奔）、把校验挪到 `startRing()` 之后（先响铃再判断），
/// 或者干脆改掉 `ACTION_ALARM` 常量值来"让测试变绿"，测试立刻红。
///
/// **行为验证（熄屏 + 锁屏下全屏页真的能盖住锁屏）属真机复验**，本文件不冒充它。
void main() {
  final androidRoot = p.join('android', 'app', 'src', 'main');
  final kotlinRoot =
      p.join(androidRoot, 'kotlin', 'com', 'efficiency', 'app', 'efficiency_app', 'alarm');

  final manifest = File(p.join(androidRoot, 'AndroidManifest.xml')).readAsStringSync();
  final activity = File(p.join(kotlinRoot, 'AlarmFullScreenActivity.kt')).readAsStringSync();
  final contract = File(p.join(kotlinRoot, 'AlarmContract.kt')).readAsStringSync();

  // 只对**代码**做断言：注释里天然会解释"为什么不用签名级权限""ACTION_ALARM 是什么"，
  // 拿带注释的原文去断言 isNot(contains(...)) 会误判。
  final activityCode = _stripComments(activity);

  group('T14 全屏页 exported + 来源校验（结构契约）', () {
    test('T14-1: Manifest 把 AlarmFullScreenActivity 声明为 exported="true"', () {
      final block = _activityBlock(manifest, 'AlarmFullScreenActivity');
      expect(
        block,
        contains('android:exported="true"'),
        reason: '熄屏锁屏时由 SystemUI（另一个 UID）代启本页，exported=false 会挡掉这条路'
            '—— 这就是 9b「系统日志有 Displayed、屏幕上却没有」的故障形态',
      );
    });

    test('T14-2: 改 exported 之外，锁屏显示相关声明一个都没丢', () {
      final block = _activityBlock(manifest, 'AlarmFullScreenActivity');
      expect(block, contains('android:showWhenLocked="true"'));
      expect(block, contains('android:turnScreenOn="true"'));
      expect(block, contains('android:launchMode="singleInstance"'));
      expect(block, contains('android:excludeFromRecents="true"'));
    });

    test('T14-3: 不引入签名级权限（那会把要修的 SystemUI 路径重新挡死）', () {
      final block = _activityBlock(manifest, 'AlarmFullScreenActivity');
      expect(
        block,
        isNot(contains('android:permission=')),
        reason: 'SystemUI 并不持有本应用签名级别的权限，加 permission 会连它一起挡掉',
      );
    });

    test('T14-4: onCreate 有来源校验，且严格早于一切副作用', () {
      final body = _methodBody(activityCode, 'override fun onCreate(');
      expect(body, contains('isFromOwnAlarm'), reason: 'onCreate 必须过这道闸');
      expect(body, contains('finish()'), reason: '不合法来源要立刻收尾');

      final guard = body.indexOf('isFromOwnAlarm');
      // T13b 后 onCreate 里已没有 startRing/startVibration/scheduleAutoStop（响铃迁到 AlarmService），
      // 这里改成断言「剩下的副作用也都在校验之后」——同一条约束，换成当下真实的落点。
      for (final sideEffect in const [
        'setShowWhenLocked',
        'setContentView',
        'bindViews',
        'setOnClickListener',
      ]) {
        final at = body.indexOf(sideEffect);
        expect(at, greaterThan(0), reason: '$sideEffect 应当仍在 onCreate 里');
        expect(
          at,
          greaterThan(guard),
          reason: '校验必须在 $sideEffect 之前 —— 先有副作用再判断就等于没判断',
        );
      }
    });

    test('T14-5: onNewIntent 走同一道校验（singleInstance 会复用同一实例）', () {
      final body = _methodBody(activityCode, 'override fun onNewIntent(');
      expect(body, contains('isFromOwnAlarm'), reason: '复用实例的入口也必须过闸');
      expect(body, contains('finish()'), reason: '不合法来源同样要收尾');
    });

    test('T14-6: 校验是白名单语义 —— action 严格等于本应用常量', () {
      final helper = _methodBody(activityCode, 'private fun isFromOwnAlarm(');
      expect(helper, contains('AlarmContract.ACTION_ALARM'));
      expect(
        helper.replaceAll(' ', ''),
        contains('==AlarmContract.ACTION_ALARM'),
        reason: '必须是相等比较；写成 action.isNotEmpty() 之类是黑名单语义，任何 action 都能过',
      );
      expect(
        helper,
        contains('Intent?'),
        reason: 'intent 可能为 null（进程重建/异常路径），必须一起挡掉',
      );
    });

    test('T14-7: ACTION_ALARM 契约值未被改动（防止靠改常量让上面的断言变绿）', () {
      expect(
        contract,
        contains(
          'const val ACTION_ALARM = "com.efficiency.app.efficiency_app.action.ALARM"',
        ),
      );
    });

    test('T14-8: 生命周期日志补齐，且都带 keyguard 状态', () {
      for (final method in const ['onResume', 'onPause', 'onStop', 'onDestroy']) {
        final body = _methodBody(activityCode, 'override fun $method(');
        expect(body, contains('alarmLog'), reason: '$method 要留下可 grep 的日志');
        expect(
          body,
          contains('keyguard='),
          reason: '$method 要记录当时是否锁屏 —— 9b「被压住还是被销毁」的定性就靠它',
        );
        expect(body, contains('isLocked()'));
      }
    });

    test('T14-9: 本页仍只由 setFullScreenIntent 拉起（T10.5 定案未破）', () {
      expect(
        activityCode,
        isNot(contains('startActivity')),
        reason: 'T10.5 定案：本页绝不被 startActivity 拉起',
      );
    });
  });
}

/// 从 Manifest 里切出指定 activity 的那一段（本工程里它是自闭合标签）。
///
/// 直接对整份 Manifest 做 `contains` 不够：文件里有多个 activity，
/// 且注释里也会出现类名。这里匹配的是 `android:name="...类名"` 这个**属性**。
String _activityBlock(String manifest, String className) {
  final pattern = RegExp(
    '<activity[^>]*android:name="[^"]*$className"[^>]*/>',
  );
  final match = pattern.firstMatch(manifest);
  if (match == null) {
    fail('AndroidManifest.xml 里找不到自闭合的 activity $className');
  }
  return match.group(0)!;
}

/// 取出某个顶层成员的正文：从签名开始，到下一个 4 空格缩进的成员标记为止。
///
/// 直接用整份源码做 `indexOf` 判断"先后"是不准的（同名调用可能在别的方法里先出现），
/// 所以先切片再断言。嵌套层级更深的代码（局部函数 / 匿名对象）缩进 >4 空格，
/// 不会误判为成员边界。
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
