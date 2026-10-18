import 'decision_support.dart';

/// ============================================================================
/// T20 · 六条已定案 → 可执行断言
/// ============================================================================
///
/// 每条断言都是**纯函数**（[SourceSet] → [DecisionResult]），因此
/// `decision_mechanism_selftest_test.dart` 可以喂「注入违规的假源码」来证明它真的会红。
///
/// 断言只对**代码**成立（注释已剥离）——KDoc 里写「以前用电源键」「这里不碰 MediaPlayer」
/// 属于文档说明，不该被当成违规。

// ------------------------------------------------------------------ 路径常量

const String kManifestPath = 'android/app/src/main/AndroidManifest.xml';

const String kAlarmDir =
    'android/app/src/main/kotlin/com/efficiency/app/efficiency_app/alarm';

const String kEditorPath = 'lib/features/alarm/presentation/alarm_editor.dart';

const String kSupportPath = 'test/decisions/decision_support.dart';

String ktFile(String name) => '$kAlarmDir/$name.kt';

String get kActivityPath => ktFile('AlarmFullScreenActivity');
String get kServicePath => ktFile('AlarmService');
String get kReceiverPath => ktFile('AlarmReceiver');
String get kNotificationsPath => ktFile('AlarmNotifications');

/// 工程源码的扫描范围（**不含** `build/`、`.dart_tool/` 等产物目录）。
SourceSet loadProjectSources() => SourceSet.loadTree(
      const ['android/app/src/main', 'lib', 'test/decisions'],
      extensions: const ['.kt', '.dart', '.xml'],
    );

// ------------------------------------------------------------------ 小工具

const List<String> _shippedPrefixes = ['android/', 'lib/'];

/// 逐字节找出行号（1 起）。
int lineOf(String text, int index) {
  var line = 1;
  for (var i = 0; i < index && i < text.length; i++) {
    if (text[i] == '\n') line++;
  }
  return line;
}

/// 从 manifest 里切出所有 `<service ... />` / `<service>...</service>` 块。
///
/// 先找**开标签的结束 `>`**，再按它前一个字符是否为 `/` 判断自闭；非自闭才去找 `</service>`。
/// （不能用「第一个 `/>`」，因为服务内的 `<property ... />` 会先出现，导致块被腰斩。）
List<({int start, String block})> serviceBlocks(String manifest) {
  final out = <({int start, String block})>[];
  var idx = 0;
  while (true) {
    final start = manifest.indexOf('<service', idx);
    if (start < 0) break;
    final openEnd = manifest.indexOf('>', start);
    if (openEnd < 0) break;
    final selfClosing = openEnd > start && manifest[openEnd - 1] == '/';
    int end;
    if (selfClosing) {
      end = openEnd + 1;
    } else {
      final endTag = manifest.indexOf('</service>', openEnd);
      end = endTag >= 0 ? endTag + '</service>'.length : manifest.length;
    }
    out.add((start: start, block: manifest.substring(start, end)));
    idx = end;
  }
  return out;
}

DecisionResult _pass(
  DecisionCheck meta, {
  List<String> evidence = const [],
  DecisionStatus status = DecisionStatus.landed,
  String? limitation,
}) =>
    DecisionResult(
      id: meta.id,
      title: meta.title,
      reference: meta.reference,
      status: status,
      evidence: evidence,
      limitation: limitation,
    );

DecisionResult _fail(
  DecisionCheck meta,
  List<SourceHit> violations, {
  List<String> evidence = const [],
  String? limitation,
}) =>
    DecisionResult(
      id: meta.id,
      title: meta.title,
      reference: meta.reference,
      status: DecisionStatus.violated,
      evidence: evidence,
      violations: violations,
      limitation: limitation,
    );

// ============================================================================
// D1 · 禁止无条件 startActivity 拉全屏（PRD v2.2 硬伤 1）
// ============================================================================

final DecisionCheck d1NoUnconditionalStartActivity = DecisionCheck(
  id: 'D1',
  title: '禁止无条件 startActivity 拉全屏',
  reference: 'PRD v2.2 硬伤 1（后台启动 Activity 受限，10+ 直接抛异常）',
  checksWhat: '① `AlarmReceiver.kt` / `AlarmService.kt` 的**代码**里没有裸 `startActivity(`；'
      '② 全工程代码里没有「同一行同时出现 `startActivity(` 与 `AlarmFullScreenActivity`」；'
      '③ 正向：全屏入口走 `AlarmNotifications` 的 `setFullScreenIntent(`。',
  run: (sources) {
    final violations = <SourceHit>[];

    // ① 到点路径的两个文件不得有裸 startActivity
    for (final p in [kReceiverPath, kServicePath]) {
      if (!sources.has(p)) {
        violations.add(SourceHit(p, 1, '<文件缺失，无法断言>'));
        continue;
      }
      violations.addAll(sources.hits(p, 'startActivity(', codeOnly: true));
    }

    // ② 任何地方都不许用 startActivity 拉起全屏页
    for (final p in sources.pathsUnder(_shippedPrefixes)) {
      if (!p.endsWith('.kt')) continue;
      for (final h in sources.hits(p, 'startActivity(', codeOnly: true)) {
        if (h.text.contains('AlarmFullScreenActivity')) violations.add(h);
      }
    }

    // ③ 正向证据
    final fullScreen = sources.hits(kNotificationsPath, 'setFullScreenIntent(');
    final allStart = <SourceHit>[];
    for (final p in sources.pathsUnder(_shippedPrefixes)) {
      if (!p.endsWith('.kt')) continue;
      allStart.addAll(sources.hits(p, 'startActivity(', codeOnly: true));
    }

    final evidence = <String>[
      '`AlarmNotifications.kt` 里 `setFullScreenIntent(` 命中 ${fullScreen.length} 处：'
          '${fullScreen.map((h) => '${h.path}:${h.line}').join('、')}',
      '全工程代码里 `startActivity(` 共 ${allStart.length} 处'
          '（${allStart.map((h) => '${h.path}:${h.line}').join('、')}）'
          '—— 这些是「用户亲手点『去开启』后打开系统设置页」，'
          '与「到点无条件拉起全屏」是两件事；断言①只约束到点路径。',
    ];

    if (fullScreen.isEmpty) {
      violations.add(SourceHit(kNotificationsPath, 1, '<未找到 setFullScreenIntent(，全屏入口不成立>'));
    }

    return violations.isEmpty
        ? _pass(d1NoUnconditionalStartActivity, evidence: evidence)
        : _fail(d1NoUnconditionalStartActivity, violations, evidence: evidence);
  },
);

// ============================================================================
// D2 · 禁止 KEYCODE_POWER 拦截（PRD v2.2 硬伤 2）
// ============================================================================

final DecisionCheck d2NoKeycodePower = DecisionCheck(
  id: 'D2',
  title: '禁止 KEYCODE_POWER 拦截',
  reference: 'PRD v2.2 硬伤 2（电源键事件不向普通应用分发，拦不到）',
  checksWhat: '`android/app/src/main` + `lib` 的**代码**里不出现 `KEYCODE_POWER`'
      '（注释里的说明不算违规；已同时统计原文出现次数并逐条列出，不做隐藏）。',
  run: (sources) {
    // 用「相邻字符串字面量」拼出来：源码里不会出现完整的禁则 token，
    // 因此对全仓 grep 该 token 也不会被检查器自身污染（同时满足 lint）。
    const token = 'KEYCODE' r'_POWER';
    final violations = <SourceHit>[];
    final rawMentions = <SourceHit>[];

    for (final p in sources.pathsUnder(_shippedPrefixes)) {
      violations.addAll(sources.hits(p, token, codeOnly: true));
      rawMentions.addAll(sources.hits(p, token, codeOnly: false));
    }

    final commentOnly = rawMentions.length - violations.length;
    final evidence = <String>[
      '代码中命中 ${violations.length} 处（要求 0）',
      '原文命中 ${rawMentions.length} 处，其中 $commentOnly 处位于注释（文档说明，按设计不算违规）：'
          '${rawMentions.map((h) => '${h.path}:${h.line}').join('、')}',
    ];

    return violations.isEmpty
        ? _pass(d2NoKeycodePower, evidence: evidence)
        : _fail(d2NoKeycodePower, violations, evidence: evidence);
  },
);

// ============================================================================
// D3 · 参数一律回表读，不走 Intent extra（ADR-008）
// ============================================================================

final DecisionCheck d3ParamsFromTable = DecisionCheck(
  id: 'D3',
  title: '参数一律回表读，不走 Intent extra',
  reference: 'ADR-008（`scheduled_alarms` 是参数的唯一真源，Intent 只带 taskId）',
  checksWhat: '① 正向：`AlarmService.kt` 的代码里存在 DB 读取（`AlarmStore.`）；'
      '② 反向：闹钟包内所有 `get*Extra(...)` 的 key 必须落在白名单内'
      '（`EXTRA_TASK_ID` + 两个**控制标记**，控制标记不是响铃参数，逐条给了理由）；'
      '③ 反向：`AlarmService.kt` 里不出现任何「闹钟参数形态」的 extra 名'
      '（`EXTRA_RINGTONE` / `EXTRA_VOLUME` / `EXTRA_TITLE` / `EXTRA_SOUND`）——'
      '这条才是 ADR-008 的核心防护。',
  run: (sources) {
    /// 白名单（3 条，逐条给理由；②③ 分工不同 —— ③ 才是 ADR-008 的核心）：
    ///
    /// - `EXTRA_TASK_ID`：ADR-008 明确允许的唯一标识，参数一律凭它回表读。
    /// - `EXTRA_AUTO_STOP_MS`：T13b 留的**测试专用覆盖值**（AUTO_STOP 由 5 分钟缩到 40 秒，
    ///   免重新构建即可验），**不是响铃参数**。
    /// - `EXTRA_DEGRADED_NO_FGS`：**降级路径的控制标记**（FGS 起不来 → 不走 startForeground），
    ///   同样**不是响铃参数**。
    ///   ⚠ 如实标注：它是「调用方已知的状态」被塞进 Intent，属于耦合；
    ///   更干净的做法是服务端自查（如 try/catch startForeground 或查通知权限）后自行判定。
    ///   这不违反 ADR-008（不代表响铃参数外泄），故本次**只允许并登记**，不擅自改 T13b 已验收代码。
    const allowedExtraKeys = {
      'EXTRA_TASK_ID',
      'EXTRA_AUTO_STOP_MS',
      'EXTRA_DEGRADED_NO_FGS',
    };

    final violations = <SourceHit>[];
    final extraReads = <SourceHit>[];

    final extraCallRe = RegExp(r'get(?:String|Int|Boolean|Long)Extra\(\s*([A-Za-z0-9_.]+)');
    for (final p in sources.pathsUnder([kAlarmDir])) {
      if (!p.endsWith('.kt')) continue;
      for (final h in sources.hits(p, extraCallRe, codeOnly: true)) {
        final m = extraCallRe.firstMatch(h.text.trim());
        if (m == null) continue;
        final key = m.group(1)!.split('.').last;
        extraReads.add(h);
        if (!allowedExtraKeys.contains(key)) violations.add(h);
      }
    }

    if (!sources.has(kServicePath)) {
      violations.add(SourceHit(kServicePath, 1, '<文件缺失，无法断言>'));
    } else {
      // ① 正向：服务必须回表读
      final dbReads = sources.hits(kServicePath, RegExp(r'AlarmStore\.\w+'));
      if (dbReads.isEmpty) {
        violations.add(SourceHit(kServicePath, 1, '<AlarmService 里找不到任何 DB 读取（AlarmStore.）>'));
      }
      // ③ 参数形态的 extra 一个都不许有
      final paramLike = RegExp(r'EXTRA_(?:RINGTONE|VOLUME|TITLE|SOUND|SNOOZE_MINUTES)');
      violations.addAll(sources.hits(kServicePath, paramLike, codeOnly: true));
    }

    final evidence = <String>[
      '闹钟包内 `get*Extra(` 读取共 ${extraReads.length} 处：'
          '${extraReads.map((h) => '${h.path.split('/').last}:${h.line}').join('、')}'
          '（白名单外的即违规）',
      '`AlarmService.kt` 里 `AlarmStore.` 命中 '
          '${sources.hits(kServicePath, RegExp(r'AlarmStore\.\w+')).length} 处 —— '
          '响铃参数（标题 / 铃声 / 音量 / 贪睡）全部由 `AlarmStore.loadByTask()` 回表取。',
    ];

    return violations.isEmpty
        ? _pass(d3ParamsFromTable, evidence: evidence)
        : _fail(d3ParamsFromTable, violations, evidence: evidence);
  },
);

// ============================================================================
// D4 · 界面必须如实告知档位（PRD §3.3 约束 4）
// ============================================================================

final DecisionCheck d4UiReportsTier = DecisionCheck(
  id: 'D4',
  title: '界面如实告知档位',
  reference: 'PRD v2 §3.3 约束 4（界面必须如实告知当前档位）',
  checksWhat: '`lib/features/alarm/presentation/**` 里**至少有一个**页面：'
      '`final x = await AlarmScheduler.canScheduleExactAlarms()`，'
      '**且该值在后续条件分支里被使用**（只打日志不算「告知用户」）。'
      '范围限定在闹钟相关页面 —— 档位是闹钟的概念，其它页面不需要引用它。',
  run: (sources) {
    final candidates = sources
        .pathsUnder(const ['lib/features/alarm/presentation/'])
        .where((x) => x.endsWith('.dart'))
        .toList()
      ..sort();

    final violations = <SourceHit>[];
    final evidence = <String>[];
    final satisfiedBy = <String>[];
    final notReferencing = <String>[];

    final assignRe =
        RegExp(r'final\s+(\w+)\s*=\s*await\s+AlarmScheduler\.canScheduleExactAlarms\(\)');

    for (final p in candidates) {
      final code = sources.code(p);
      final m = assignRe.firstMatch(code);
      if (m == null) {
        notReferencing.add(p);
        continue;
      }
      final varName = m.group(1)!;
      final rest = code.substring(m.end);
      final bm = RegExp('if\\s*\\([^)]*\\b$varName\\b').firstMatch(rest);
      if (bm == null) {
        notReferencing.add(p);
        continue;
      }
      satisfiedBy.add(p);
      for (final h in sources.hits(p, assignRe)) {
        evidence.add('读取真实档位：`${h.path}:${h.line}` → `${h.text.trim()}`');
      }
      evidence.add('并在分支中被使用：`$p:${lineOf(code, m.end + bm.start)}`');
    }

    // 「至少一个页面如实用了档位」——只有一个页面用是正常的，不算违规
    if (satisfiedBy.isEmpty) {
      if (candidates.isEmpty) {
        violations.add(
          const SourceHit('lib/features/alarm/presentation/', 1, '<找不到任何闹钟页面文件>'),
        );
      } else {
        for (final p in notReferencing) {
          violations.add(SourceHit(p, 1, '<未取用 canScheduleExactAlarms() 的真实返回值>'));
        }
      }
    } else if (notReferencing.isNotEmpty) {
      evidence.add('未引用档位的闹钟页面（按设计允许，仅登记）：${notReferencing.join('、')}');
    }

    const limitation = '本断言只证明「UI 消费了真实返回值并用于分支」，'
        '**不覆盖**「常驻显示当前档位」的界面（那属 T18 的 UI 呈现范围），也不校验文案措辞。'
        '人工核对方式：任务列表点铃铛保存 → 若当前是近似档，应弹出「开启闹钟和提醒权限」引导；'
        '在系统设置里关掉该权限后重试，引导应再次出现。';

    return violations.isEmpty
        ? _pass(d4UiReportsTier, evidence: evidence, limitation: limitation)
        : _fail(d4UiReportsTier, violations, evidence: evidence, limitation: limitation);
  },
);

// ============================================================================
// D5 · FGS 必须有 foregroundServiceType（T17）
// ============================================================================

final DecisionCheck d5FgsType = DecisionCheck(
  id: 'D5',
  title: '前台服务必须声明 foregroundServiceType',
  reference: 'T17 定案 / ADR-007（API 34+ 未声明类型会启动失败）',
  checksWhat: '从 `AndroidManifest.xml` 切出**每一个** `<service>` 块：'
      '每块都必须含 `android:foregroundServiceType=`；'
      '`AlarmService` 必须是 `specialUse` 且有 `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` 用途说明；'
      '并声明 `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE` 两个权限。',
  run: (sources) {
    final violations = <SourceHit>[];
    final evidence = <String>[];

    if (!sources.has(kManifestPath)) {
      return _fail(d5FgsType, const [SourceHit(kManifestPath, 1, '<文件缺失，无法断言>')]);
    }

    // 注释也会提到 <service>，先剥离以免误切
    final manifest = sources.code(kManifestPath);
    final blocks = serviceBlocks(manifest);
    evidence.add('`<service>` 块共 ${blocks.length} 个');

    if (blocks.isEmpty) {
      violations.add(const SourceHit(kManifestPath, 1, '<未找到任何 <service> 声明>'));
    }

    for (final b in blocks) {
      final line = lineOf(manifest, b.start);
      final nameMatch = RegExp(r'android:name="([^"]+)"').firstMatch(b.block);
      final name = nameMatch?.group(1) ?? '?';
      if (!b.block.contains('foregroundServiceType=')) {
        violations.add(SourceHit(kManifestPath, line, '<service $name 缺少 android:foregroundServiceType=>'));
      } else {
        evidence.add('`<service $name>` → '
            '`${RegExp(r'android:foregroundServiceType="([^"]+)"').firstMatch(b.block)?.group(1)}`'
            '（第 $line 行）');
      }
      if (name.contains('AlarmService') &&
          !b.block.contains('foregroundServiceType="specialUse"')) {
        violations.add(SourceHit(kManifestPath, line, '<AlarmService 的类型不是 specialUse>'));
      }
      if (name.contains('AlarmService') && !b.block.contains('PROPERTY_SPECIAL_USE_FGS_SUBTYPE')) {
        violations.add(SourceHit(kManifestPath, line, '<AlarmService 缺少 specialUse 用途说明 <property>>'));
      }
    }

    for (final perm in const [
      'android.permission.FOREGROUND_SERVICE"',
      'android.permission.FOREGROUND_SERVICE_SPECIAL_USE"',
    ]) {
      final hits = sources.hits(kManifestPath, perm, codeOnly: false);
      if (hits.isEmpty) {
        violations.add(SourceHit(kManifestPath, 1, '<缺少权限声明 $perm>'));
      } else {
        evidence.add('权限 `$perm`（${hits.first.line} 行）');
      }
    }

    return violations.isEmpty
        ? _pass(d5FgsType, evidence: evidence)
        : _fail(d5FgsType, violations, evidence: evidence);
  },
);

// ============================================================================
// D6 · 响铃不得绑在 Activity 生命周期上（T13b）
// ============================================================================

final DecisionCheck d6RingDecoupled = DecisionCheck(
  id: 'D6',
  title: '响铃不得绑在 Activity 生命周期上',
  reference: 'T13b 定案（真机实测：Activity 被 ROM 收掉后铃只响 211 毫秒）',
  checksWhat: '① 反向：`AlarmFullScreenActivity.kt` 的代码里没有 `MediaPlayer` / `Vibrator` / '
      '`startRing(` / `stopRing(` / `stopRingtone(`（页面只做 UI）；'
      '② 正向：`AlarmService.kt` 持有 `MediaPlayer` + 有 `RING OWNER started` 归属日志 + '
      '`finishRing`/`stopRingtone` 收尾 + `STOP_FOREGROUND_REMOVE`；'
      '③ 反向：`AlarmService.kt` 的代码里不引用 `AlarmFullScreenActivity`（互不依赖）。',
  run: (sources) {
    final violations = <SourceHit>[];
    final evidence = <String>[];

    if (!sources.has(kActivityPath)) {
      violations.add(SourceHit(kActivityPath, 1, '<文件缺失，无法断言>'));
    } else {
      final forbidden = RegExp(r'MediaPlayer|Vibrator|startRing\(|stopRing\(|stopRingtone\(');
      violations.addAll(sources.hits(kActivityPath, forbidden, codeOnly: true));
      evidence.add('`AlarmFullScreenActivity.kt` 代码中 `MediaPlayer|Vibrator|stopRing` 命中 '
          '${sources.hits(kActivityPath, forbidden, codeOnly: true).length} 处（要求 0）');
    }

    if (!sources.has(kServicePath)) {
      violations.add(SourceHit(kServicePath, 1, '<文件缺失，无法断言>'));
    } else {
      final checks = <String, Pattern>{
        'MediaPlayer': 'MediaPlayer',
        'RING OWNER started 归属日志': 'RING OWNER started',
        'finishRing/stopRingtone 收尾': RegExp(r'fun\s+(?:finishRing|stopRingtone)\('),
        'STOP_FOREGROUND_REMOVE': 'STOP_FOREGROUND_REMOVE',
      };
      checks.forEach((label, pattern) {
        final hits = sources.hits(kServicePath, pattern);
        if (hits.isEmpty) {
          violations.add(SourceHit(kServicePath, 1, '<AlarmService 缺少 $label>'));
        } else {
          evidence.add('服务侧 `$label` 命中（${hits.first.path.split('/').last}:${hits.first.line}）');
        }
      });
      // ③ 服务不得依赖页面
      violations.addAll(sources.hits(kServicePath, 'AlarmFullScreenActivity', codeOnly: true));
    }

    return violations.isEmpty
        ? _pass(d6RingDecoupled, evidence: evidence)
        : _fail(d6RingDecoupled, violations, evidence: evidence);
  },
);

// ============================================================================
// D7 · 机制自检（避开两个已知坑）
// ============================================================================

final DecisionCheck d7MechanismSelfCheck = DecisionCheck(
  id: 'D7',
  title: '校验机制自身避开两个已知坑',
  reference: 'T20 交接提醒：坑 1 `File.exists()` 是 Future；坑 2 `expect(Future, isTrue)` 永远失败',
  checksWhat: '`test/decisions/**` 的代码里：'
      '① 不出现异步的 `.exists()`（必须用 `existsSync()`）；'
      '② 不出现 `expect(await ...)`（把 Future 交给 expect 就是坑 2）；'
      '③ 正向：底座里存在 `existsSync()`。',
  run: (sources) {
    final violations = <SourceHit>[];
    final evidence = <String>[];

    // 用相邻字符串字面量拆开写：源码里不会出现完整的禁则 token
    final asyncExistsRe = RegExp(r'\.exists' r'\(\)');
    final futureExpectRe = RegExp(r'expect' r'\(\s*await');

    final testPaths = sources.pathsUnder(const ['test/decisions/']).toList()..sort();
    evidence.add('扫描本机制自身 ${testPaths.length} 个文件');

    for (final p in testPaths) {
      // dropStrings：本文件的**文案**里就写着 `.exists()`，那是字符串不是调用
      violations.addAll(sources.hits(p, asyncExistsRe, codeOnly: true, dropStrings: true));
      violations.addAll(sources.hits(p, futureExpectRe, codeOnly: true, dropStrings: true));
    }

    final syncHits = sources.hits(kSupportPath, 'existsSync()');
    if (syncHits.isEmpty) {
      violations.add(const SourceHit(kSupportPath, 1, '<底座里找不到 existsSync()>'));
    } else {
      evidence.add('`$kSupportPath:${syncHits.first.line}` 使用 `existsSync()`（同步，避开坑 1）');
    }

    return violations.isEmpty
        ? _pass(d7MechanismSelfCheck, evidence: evidence)
        : _fail(d7MechanismSelfCheck, violations, evidence: evidence);
  },
);

/// 注册表：**加定案必须同时加断言**，否则 `SUM` 汇总用例会红（禁止静默通过）。
/// （不能是 `const` —— 元素是 `final` 的 `DecisionCheck` 实例。）
final List<DecisionCheck> kDecisionRegistry = [
  d1NoUnconditionalStartActivity,
  d2NoKeycodePower,
  d3ParamsFromTable,
  d4UiReportsTier,
  d5FgsType,
  d6RingDecoupled,
  d7MechanismSelfCheck,
];
