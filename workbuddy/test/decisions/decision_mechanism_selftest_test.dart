import 'package:flutter_test/flutter_test.dart';

import 'decision_checks.dart';
import 'decision_support.dart';

/// ============================================================================
/// T20 · **机制自检** —— 证明这 7 条断言不是橡皮图章
/// ============================================================================
///
/// 一个「永远通过」的断言和没有断言一样糟。所以这里对每条定案
/// **注入一处真实形态的违规**（不是随便加个字符），然后要求：
///
/// 1. 注入后该条必须变 `violated`（否则这条断言是空的）；
/// 2. 必须给出违规点；
/// 3. 失败信息里必须**出现被改的那个文件路径**（对应验收要求「指出在哪条定案、哪个文件」）。
///
/// 注入到内存里的 `SourceSet`，**不会改动磁盘上的任何源文件**。
///
/// 注入的违规都取自真实的坑：
/// - D1 用 `startActivity(Intent(context, AlarmFullScreenActivity::class.java))`（PRD 硬伤 1 形态）；
/// - D3 用 `intent.getStringExtra(EXTRA_RINGTONE)`（**对照组被抓到的真实违规**）；
/// - D6 用「Activity 里持有 MediaPlayer」（真机实测「铃只响 211 毫秒」的成因）。

typedef _Mutation = ({String path, String Function(String raw) mutate});

_Mutation _mutationFor(String id) {
  switch (id) {
    case 'D1':
      return (
        path: kReceiverPath,
        mutate: (raw) => '$raw\n'
            '            context.startActivity('
            'Intent(context, AlarmFullScreenActivity::class.java))\n',
      );
    case 'D2':
      return (
        path: kReceiverPath,
        // 用相邻字符串字面量拼，免得这条自检代码本身带出完整的禁则 token
        mutate: (raw) =>
            '$raw\n    private val forbiddenKey = KeyEvent.${'KEYCODE' r'_POWER'}\n',
      );
    case 'D3':
      return (
        path: kServicePath,
        mutate: (raw) =>
            '$raw\n        val ringtone = intent.getStringExtra(AlarmContract.EXTRA_RINGTONE)\n',
      );
    case 'D4':
      return (
        path: kEditorPath,
        mutate: (raw) => raw.replaceAll('canScheduleExactAlarms()', 'canScheduleExactAlarmsStub()'),
      );
    case 'D5':
      return (
        path: kManifestPath,
        mutate: (raw) => raw.replaceAll('android:foregroundServiceType="specialUse"', ''),
      );
    case 'D6':
      return (
        path: kActivityPath,
        mutate: (raw) => '$raw\n    private var leakedPlayer: MediaPlayer? = null\n',
      );
    case 'D7':
      return (
        path: kSupportPath,
        mutate: (raw) => raw.replaceAll('existsSync()', 'exists()'),
      );
    default:
      throw StateError('定案 $id 没有定义反向验证用的违规注入 —— 新增定案时必须同时提供');
  }
}

void main() {
  final realSources = loadProjectSources();

  group('T20 · 机制自检（注入违规 → 必须报红）', () {
    for (final check in kDecisionRegistry) {
      test('${check.id}  反向验证：注入违规必须被抓到，且失败信息指出文件', () {
        // 前提：真实源码本来就该通过（否则这条自检自己会红，说明工程确实有未落地项）
        expect(
          check.run(realSources).status,
          isNot(DecisionStatus.violated),
          reason: '真实源码未通过 ${check.id} —— 先修工程再谈机制',
        );

        final mutation = _mutationFor(check.id);
        final mutated = realSources.mutate(mutation.path, mutation.mutate);
        // 注入必须真的改到东西（防止 replaceAll 没匹配上导致「假通过」）
        expect(
          mutated.raw(mutation.path),
          isNot(realSources.raw(mutation.path)),
          reason: '违规没注入进去（${mutation.path} 内容未变化）—— 这条自检是无效的',
        );

        final result = check.run(mutated);
        expect(
          result.status,
          DecisionStatus.violated,
          reason: '注入违规后 ${check.id} 仍然放行 —— 这条断言是橡皮图章',
        );
        expect(result.violations, isNotEmpty, reason: '${check.id} 报红但没给出违规点');
        expect(
          result.failureMessage,
          contains(mutation.path),
          reason: '失败信息必须指到具体文件（期望包含 ${mutation.path}）',
        );
      });
    }
  });
}
