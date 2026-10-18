import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// T11 · `BOOT_COMPLETED` 开机重建 —— **结构契约测试**。
///
/// ## 这个文件测的是什么（不夸大）
///
/// `BootReceiver` / `AlarmScheduler` 是 Kotlin，跑在 Android 的广播与 AlarmManager 里。
/// `flutter test` 是 Dart VM 测试，**执行不了它们**。所以这里断言的是**结构契约**：
///
/// 1. Manifest 是否真的注册了 receiver（`exported` / `directBootAware` / 两个 action）；
/// 2. 原生侧是否**复用** T10 的读表与调度，而不是另起一套（任务单的硬要求）；
/// 3. 「过期 `once` 跳过」「幂等靠同一 PendingIntent」「原生对表只读」这三条设计约束，
///    在源码里是否有对应的、可被后续改动破坏的落点。
///
/// 这些是**回归防护**：一旦有人把 receiver 删了、把 `exported` 改回 false、
/// 或者在 BootReceiver 里塞进第二套 SQL，测试立刻红。
///
/// **行为验证（重建后 AlarmManager 真的武装 / 过期的真的被跳过 / 幂等）属阶段 B 真机**，
/// 本文件不冒充它。阶段 A 的模拟器自测证据见 `wb-outbox.md`。
void main() {
  final androidRoot = p.join('android', 'app', 'src', 'main');
  final kotlinRoot = p.join(androidRoot, 'kotlin', 'com', 'efficiency', 'app', 'efficiency_app', 'alarm');

  final manifest = File(p.join(androidRoot, 'AndroidManifest.xml')).readAsStringSync();
  final bootReceiver = File(p.join(kotlinRoot, 'BootReceiver.kt')).readAsStringSync();
  final scheduler = File(p.join(kotlinRoot, 'AlarmScheduler.kt')).readAsStringSync();
  final store = File(p.join(kotlinRoot, 'AlarmStore.kt')).readAsStringSync();
  final channel = File(p.join('lib', 'core', 'platform', 'alarm_channel.dart')).readAsStringSync();

  // 「有没有另起一套读表/调度」这类断言必须只看**代码**：
  // BootReceiver 的 KDoc 里天然会提到 AlarmStore / AlarmManager 来说明「我没重复实现它们」，
  // 拿带注释的原文去断言 isNot(contains(...)) 会误判。
  final bootCode = _stripComments(bootReceiver);
  final schedulerCode = _stripComments(scheduler);
  final storeCode = _stripComments(store);

  group('T11 开机重建（结构契约）', () {
    test('T11-1: Manifest 声明 RECEIVE_BOOT_COMPLETED', () {
      expect(
        manifest,
        contains('android.permission.RECEIVE_BOOT_COMPLETED'),
        reason: '没有这条权限，系统不会把开机广播投递进来',
      );
    });

    test('T11-2: BootReceiver 注册为 exported=true 且 directBootAware=true', () {
      final block = _receiverBlock(manifest, 'BootReceiver');
      expect(
        block,
        contains('android:exported="true"'),
        reason: '系统是另一个进程，receiver 不 exported 就收不到广播',
      );
      expect(
        block,
        contains('android:directBootAware="true"'),
        reason: '不声明 directBootAware 就收不到 LOCKED_BOOT_COMPLETED',
      );
    });

    test('T11-3: intent-filter 同时监听 BOOT_COMPLETED 与 LOCKED_BOOT_COMPLETED', () {
      final block = _receiverBlock(manifest, 'BootReceiver');
      expect(block, contains('android.intent.action.BOOT_COMPLETED'));
      expect(block, contains('android.intent.action.LOCKED_BOOT_COMPLETED'));
    });

    test('T11-4: BootReceiver 复用 AlarmScheduler.rescheduleAll，不另起一套读表/调度', () {
      expect(
        bootCode,
        contains('AlarmScheduler.rescheduleAll'),
        reason: '重建入口必须是 T10.5 已有的那一个',
      );
      expect(bootCode, isNot(contains('AlarmStore')), reason: '不该自己读表（那是 AlarmStore 的职责）');
      expect(bootCode, isNot(contains('SQLiteDatabase')), reason: '更不该自己开库');
      expect(bootCode, isNot(contains('AlarmManager')), reason: '也不该自己调度');
    });

    test('T11-5: 全量重建跳过已过期的 once', () {
      expect(
        schedulerCode,
        contains('isExpiredOnce'),
        reason: '过去的触发时刻交给 setExactAndAllowWhileIdle 会立刻响',
      );
      expect(schedulerCode, contains('skippedExpiredOnce'), reason: '跳过条数要能进日志/报告，不能静默');
      expect(
        bootCode,
        contains('LOCKED_BOOT_COMPLETED'),
        reason: '解锁前读不到库，必须有显式的降级分支',
      );
      expect(
        bootCode,
        contains('DEGRADED'),
        reason: '降级要留下可 grep 的日志，而不是静默返回',
      );
    });

    test('T11-6: 幂等 —— 重建沿用同一个 PendingIntent，set* 为覆盖语义', () {
      expect(schedulerCode, contains('AlarmContract.alarmRequestCode(taskId)'));
      expect(schedulerCode, contains('FLAG_UPDATE_CURRENT'));
      expect(
        schedulerCode,
        isNot(contains('FLAG_CANCEL_CURRENT')),
        reason: '同 requestCode 的 set* 本身就是覆盖，不需要先 cancel（多一次窗口期）',
      );
    });

    test('T11-7: 原生侧对 scheduled_alarms 只读（ADR-008）', () {
      expect(storeCode, contains('OPEN_READONLY'));
      expect(storeCode, isNot(contains('OPEN_READWRITE')), reason: '原生只读真源，不写库');
      expect(storeCode, isNot(contains('execSQL')), reason: '没有任何写语句的口子');
      expect(schedulerCode, isNot(contains('OPEN_READWRITE')));
    });

    test('T11-8: Dart 侧契约未改（通道名 + rescheduleAll 仍在）', () {
      expect(channel, contains("MethodChannel('efficiency_app/alarm')"));
      expect(channel, contains("invokeMethod('rescheduleAll')"));
    });

    test('T11-9: LOCKED_BOOT_COMPLETED 按 isUserUnlocked 分流，不无条件宣称「库不可读」', () {
      // 模拟器实测教训：LOCKED_BOOT_COMPLETED 只代表「Direct Boot 阶段」，
      // **不等于**「此刻一定未解锁」—— 设备没有安全锁屏时它到达时 userUnlocked 已经是 true。
      // 若无条件记「DB unreadable」，就会和同一行日志里的 userUnlocked=true 互相打脸。
      final locked = _actionBranch(bootCode, 'LOCKED_BOOT_COMPLETED');
      expect(
        locked,
        contains('rescheduleAll'),
        reason: '已解锁时该分支必须真的重建，而不是一律跳过',
      );
      expect(
        locked,
        contains('unlocked'),
        reason: '必须按 unlocked 分流，才可能正确区分「真读不到」与「其实读得到」',
      );
      expect(
        bootCode,
        contains('userUnlocked=true'),
        reason: '已解锁分支要留下可 grep 的日志，说明走的是另一条路',
      );
    });
  });
}

/// 取出 `when (action)` 里某个 action 对应的分支正文。
///
/// 对整份源码做 `contains` 不够精确：`DEGRADED` 这类词两个分支都有。
/// 这里定位到 `Intent.ACTION_X ->` 之后、下一个分支头之前的片段。
String _actionBranch(String code, String action) {
  final start = code.indexOf('Intent.ACTION_$action ->');
  if (start < 0) {
    fail('BootReceiver 里找不到 Intent.ACTION_$action 分支');
  }
  final tail = code.substring(start);
  final heads = RegExp(r'Intent\.ACTION_[A-Z_]+ ->|else ->').allMatches(tail).toList();
  final end = heads.length >= 2 ? heads[1].start : tail.length;
  return tail.substring(0, end);
}

/// 从 Manifest 里切出指定 receiver 的那一段。
///
/// 直接对整份 Manifest 做 `contains` 是不够的：文件里有**两个** receiver，
/// 拿整份文本去断言 `exported="true"` 会被 `AlarmReceiver` 之外的片段干扰。
///
/// 也不能简单按 `<receiver` 切分——T11 那段**注释正文里**就写了 "BootReceiver"
/// 三个字（用来解释降级策略），按纯字符串匹配会命中 `AlarmReceiver` 那一段。
/// 所以这里匹配的是 `android:name="...BootReceiver"` 这个**属性**。
String _receiverBlock(String manifest, String className) {
  final pattern = RegExp(
    '<receiver[^>]*android:name="[^"]*$className"[^>]*>[\\s\\S]*?</receiver>',
  );
  final match = pattern.firstMatch(manifest);
  if (match == null) {
    fail('AndroidManifest.xml 里找不到 receiver $className');
  }
  return match.group(0)!;
}

/// 去掉 Kotlin 的块注释与行注释，只留可执行代码。
///
/// 用于「有没有重复实现」这类断言：注释里写「我没重复实现 AlarmStore」是好事，
/// 不该被当成违规命中。
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');
