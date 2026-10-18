import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'decision_checks.dart';
import 'decision_support.dart';

/// ============================================================================
/// T20 · 「定案 → 代码」落地校验 —— 入口
/// ============================================================================
///
/// ## 这个文件是做什么的
///
/// 项目里有多份定案（ADR / 修复清单 / PRD 硬伤），但**没有任何机制保证它们被真正落地**。
/// 这里把每条定案变成**可执行断言**，用同一个入口（`flutter test`）一次跑完：
///
/// - 每条定案一个用例：**违规 → 红**，失败信息直接指出「哪条定案没落地、在哪个文件、第几行」；
/// - 末尾 `SUM` 汇总用例：**必须**凑齐注册表里所有定案（少一条就红），
///   并把逐条状态 + 未落地清单写成 `docs/decisions-landed-report.md`，**不静默通过**。
///
/// ## 为什么断言是「结构契约」而不是「行为」
///
/// `AlarmService` / `AlarmFullScreenActivity` 是 Kotlin，`flutter test` 是 Dart VM 测试，
/// 跑不起来它们。所以这里断言的是**源码结构 + Manifest**，属于**回归防护**：
/// 有人把 `MediaPlayer` 挪回 Activity、给 `AlarmService` 加一行
/// `intent.getStringExtra(EXTRA_RINGTONE)`、或删掉 `foregroundServiceType`，这里立刻红。
///
/// **反向验证**在 `decision_mechanism_selftest_test.dart`：给每条定案注入一处真实形态的违规，
/// 证明断言真的会红 —— 也就是证明这套机制不是橡皮图章。
void main() {
  final sources = loadProjectSources();
  final results = <DecisionResult>[];

  group('T20 · 定案 → 代码 落地校验', () {
    for (final check in kDecisionRegistry) {
      test('${check.id}  ${check.title}', () {
        final result = check.run(sources);
        results.add(result);
        // 断言前先取同步值（坑 2：绝不把 Future 交给 expect）
        expect(
          result.status,
          isNot(DecisionStatus.violated),
          reason: result.failureMessage,
        );
      });
    }

    test('SUM  汇总：未落地条目 + 每条断言各自检查什么', () {
      // ① 禁止静默通过：注册表里有几条定案，就必须跑出几条结果
      expect(
        results.length,
        kDecisionRegistry.length,
        reason: '注册表有 ${kDecisionRegistry.length} 条定案，但只跑了 ${results.length} 条 —— 有定案没有断言',
      );

      final report = renderReport(
        kDecisionRegistry,
        results,
        sources,
        generatedAt: DateTime.now().toString().substring(0, 19),
      );

      // ② 报告落盘，避免「测试绿了就什么都看不到」
      final out = File(p.join('docs', 'decisions-landed-report.md'));
      out.parent.createSync(recursive: true);
      out.writeAsStringSync(report);

      // ③ 未落地条目必须报出来（失败时把整张表贴进输出）
      final violated = results.where((r) => r.isViolated).toList();
      expect(violated, isEmpty, reason: '有未落地条目：\n$report');

      // ④ 每条结果都必须有正向证据，不许「空断言」
      for (final r in results) {
        expect(
          r.evidence,
          isNotEmpty,
          reason: '${r.id} 没有任何正向证据 —— 空断言等于没断言',
        );
      }

      // ⑤ 缺失的源文件也不许藏着
      expect(
        sources.missing,
        isEmpty,
        reason: '有源文件读不到，等价于「没法断言」：${sources.missing.join('、')}',
      );
    });
  });
}
