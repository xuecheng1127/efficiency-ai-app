import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// T19 · B 档（近似档）漏响兜底 —— **结构契约测试**。
///
/// ## 这个文件测的是什么（不夸大）
///
/// `AlarmScanWorker` / `MissedAlarmScanner` 是 Kotlin，跑在 WorkManager 的调度器里。
/// `flutter test` 是 Dart VM 测试，**执行不了它们**。所以这里断言的是**结构契约**：
///
/// 1. 周期任务是否真的登记了（WorkManager + 15 分钟 + 唯一工作名 + KEEP 策略）；
/// 2. 幂等是否有**落点**（判定读标记、补偿写标记、正常响也写标记、标记只前进）；
/// 3. ADR-008 是否被守住（扫描器只读 drift 库，不写 schema）；
/// 4. 「同一套时间语义」是否守得住（`AlarmOccurrence` 与 `AlarmScheduler` 的
///    weekday 映射必须逐字一致 —— 这是本次唯一的重复实现，必须有闸门）；
/// 5. R6：C 档**没有**被偷偷实现（`tierNow` 只可能返回 EXACT / INEXACT）。
///
/// **行为验证（Worker 真的每 15 分钟跑一次、真的补响、真的幂等）属模拟器实测**，本文件不冒充它。
void main() {
  final androidRoot = p.join('android', 'app', 'src', 'main');
  final kotlinRoot =
      p.join(androidRoot, 'kotlin', 'com', 'efficiency', 'app', 'efficiency_app', 'alarm');

  String kt(String name) => File(p.join(kotlinRoot, '$name.kt')).readAsStringSync();
  String strip(String s) => s
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
  String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

  final appGradle = File(p.join('android', 'app', 'build.gradle.kts')).readAsStringSync();
  final manifest = File(p.join(androidRoot, 'AndroidManifest.xml')).readAsStringSync();
  final contract = kt('AlarmContract');
  final worker = kt('AlarmScanWorker');
  final scanner = kt('MissedAlarmScanner');
  final markers = kt('AlarmFireMarkers');
  final scheduler = kt('AlarmScanScheduler');
  final occurrence = kt('AlarmOccurrence');
  final alarmScheduler = kt('AlarmScheduler');
  final receiver = kt('AlarmReceiver');
  final mainActivity = File(
    p.join(androidRoot, 'kotlin', 'com', 'efficiency', 'app', 'efficiency_app', 'MainActivity.kt'),
  ).readAsStringSync();
  final dartChannel =
      File(p.join('lib', 'core', 'platform', 'alarm_channel.dart')).readAsStringSync();

  final workerCode = strip(worker);
  final scannerCode = strip(scanner);
  final markersCode = strip(markers);
  final schedulerCode = strip(scheduler);
  final occurrenceCode = strip(occurrence);
  final alarmSchedulerCode = strip(alarmScheduler);
  final receiverCode = strip(receiver);

  group('T19 B 档兜底（结构契约）', () {
    test('S1: gradle 引入了 WorkManager', () {
      expect(appGradle, contains('androidx.work:work-runtime-ktx'));
    });

    test('S2: 周期任务登记 —— 15 分钟 + 唯一工作名 + KEEP（不会重置已有周期）', () {
      expect(squash(schedulerCode), contains('INTERVAL_MINUTES = 15L'),
          reason: 'R2：平台周期最小值就是 15 分钟，选它把漏响延迟压到最小');
      expect(schedulerCode, contains('PeriodicWorkRequestBuilder<AlarmScanWorker>'));
      expect(schedulerCode, contains('enqueueUniquePeriodicWork'));
      expect(schedulerCode, contains('ExistingPeriodicWorkPolicy.KEEP'),
          reason: '每次启动都登记一次，KEEP 才不会把已有周期重置');
      expect(schedulerCode, contains('WORK_NAME'));
    });

    test('S3: 应用启动时登记（且工作名唯一）', () {
      expect(mainActivity, contains('AlarmScanScheduler.ensureScheduled'));
      final nameLine = RegExp(r'const val WORK_NAME = "([^"]+)"').firstMatch(scheduler);
      expect(nameLine, isNotNull);
    });

    test('S4: Worker 扫一遍并补响，日志带 scanned / missed / compensated 计数', () {
      expect(workerCode, contains('MissedAlarmScanner.scan'));
      expect(workerCode, contains('MissedAlarmScanner.compensate'));
      expect(workerCode, contains('scan start'));
      expect(workerCode, contains('scan complete'));
      expect(workerCode, contains('scanned='));
      expect(workerCode, contains('compensated='));
      expect(workerCode, contains('Result.retry()'),
          reason: '失败要交给 WorkManager 退避重试，不能静默丢掉一个周期');
    });

    test('S5: ★幂等★ 判定读标记、补偿写标记、标记只前进', () {
      // 判定：已处理时刻 >= 候选应响时刻 -> 跳过
      expect(scannerCode, contains('lastHandledMillis'));
      expect(scannerCode, contains('handled >= occurrence'));
      // 补偿：补完立刻写标记
      expect(scannerCode, contains('markHandled'));
      // 正常响过也写标记，否则扫描会把每次正常响都当漏响再补一遍
      expect(receiverCode, contains('AlarmFireMarkers.markHandled'));
      // 只前进不回退
      expect(markersCode, contains('occurrenceMillis <= current'));
      expect(markersCode, contains('commit()'), reason: 'Worker 可能随后被回收，标记不能异步写');
    });

    test('S6: 追溯窗口是有名字的常量（不是逻辑里的魔数）', () {
      expect(squash(scannerCode), contains('LOOKBACK_MILLIS = 2 * 60 * 60_000L'));
      expect(scannerCode, contains('lag > LOOKBACK_MILLIS'));
    });

    test('S7: ADR-008 未被打破 —— 扫描器只读 drift 库，不碰 schema', () {
      expect(scannerCode, contains('AlarmStore.loadAllEnabled'), reason: '参数一律回表读');
      for (final code in [scannerCode, workerCode, markersCode, schedulerCode, occurrenceCode]) {
        expect(code, isNot(contains('OPEN_READWRITE')));
        expect(code, isNot(contains('execSQL')));
      }
      for (final lower in [scannerCode.toLowerCase(), workerCode.toLowerCase()]) {
        expect(lower, isNot(contains('update scheduled_alarms')));
        expect(lower, isNot(contains('insert into')));
        expect(lower, isNot(contains('delete from')));
      }
      // manifest 也不该新增与扫描有关的权限（WorkManager 不需要额外权限）
      expect(manifest, isNot(contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')));
    });

    test('S8: 时间语义只有一份真相 —— 两份 weekday 映射必须逐字一致', () {
      const clauses = [
        'Calendar.MONDAY -> 1',
        'Calendar.TUESDAY -> 2',
        'Calendar.WEDNESDAY -> 3',
        'Calendar.THURSDAY -> 4',
        'Calendar.FRIDAY -> 5',
        'Calendar.SATURDAY -> 6',
        'else -> 7',
      ];
      for (final c in clauses) {
        expect(occurrenceCode, contains(c), reason: 'AlarmOccurrence 缺了 $c');
        expect(alarmSchedulerCode, contains(c), reason: 'AlarmScheduler 缺了 $c —— 两边开始漂移了');
      }
    });

    test('S9: R5 —— T11/T13/T13b/T14 已验证的契约没被改', () {
      // 通道名与 rescheduleAll 仍在（T11-8）
      expect(dartChannel, contains("MethodChannel('efficiency_app/alarm')"));
      expect(dartChannel, contains("invokeMethod('rescheduleAll')"));
      // 响铃归属仍是服务（T13b C3/C10）
      expect(receiverCode, contains('AlarmService.startRing'));
      expect(receiverCode, isNot(contains('MediaPlayer')));
      // 开机重建仍是那一套（T11-4）
      final boot = strip(kt('BootReceiver'));
      expect(boot, contains('AlarmScheduler.rescheduleAll'));
      expect(boot, isNot(contains('AlarmStore')));
    });

    test('S10: R4 —— 档位 API 对外可读（Dart 侧已能拿到 canScheduleExactAlarms）', () {
      expect(dartChannel, contains("invokeMethod<bool>('canScheduleExactAlarms')"));
      expect(mainActivity, contains('"canScheduleExactAlarms"'),
          reason: '通道端点仍在（T18 会用它）');
    });

    test('S11: R6 —— C 档（应用内）没有被偷偷实现', () {
      expect(
        squash(alarmSchedulerCode),
        contains('Tier.EXACT else Tier.INEXACT'),
        reason: 'tierNow 只可能在 A/B 之间选择；C 档本次只评估不实现',
      );
    });

    test('S12: 扫描日志有独立可过滤前缀（tag T19 + alarm-scan）', () {
      expect(contract, contains('LOG_TAG_SCAN = "T19"'));
      expect(contract, contains('[T19][alarm-scan]'));
    });
  });
}
