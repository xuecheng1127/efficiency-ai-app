import 'dart:io';

import 'package:path/path.dart' as p;

/// ============================================================================
/// T20 · 「定案 → 代码」落地校验机制 —— 共用底座
/// ============================================================================
///
/// ## 设计要点（为什么这样写）
///
/// 1. **全部同步读文件**：`File.exists()` 返回 `Future<bool>`，同步用会编译失败
///    （同事踩过的坑 1）。这里一律 `existsSync()` + `readAsStringSync()`。
/// 2. **断言前先取同步值**：绝不把 `Future` 交给 `expect`（坑 2）。
/// 3. **断言针对「代码」，不针对注释**：KDoc 里天然会写「以前用电源键」「这里不碰
///    MediaPlayer」这类说明；拿带注释的原文做 `isNot(contains(...))` 会全部误判。
///    所以统一先 [stripComments]，且返回值仍是**原始行文本**（行号与原文对齐，便于人读）。
/// 4. **检查项是纯函数**（[SourceSet] 进、[DecisionResult] 出）：这样
///    `decision_mechanism_selftest_test.dart` 才能喂「故意违规的假源码」，
///    证明断言真的会红 —— 也就是证明这套机制**不是橡皮图章**。

/// 定案的落地状态。
enum DecisionStatus {
  /// 已落地：断言全过。
  landed,

  /// 部分落地：断言过的部分成立，但仍有明确的未覆盖范围（会写进报告，不静默）。
  partial,

  /// 未落地 / 违规：断言失败，必须修。
  violated,
}

/// 一处命中：文件 + 行号 + **原始行文本**。
class SourceHit {
  final String path;
  final int line;
  final String text;

  const SourceHit(this.path, this.line, this.text);

  @override
  String toString() => '$path:$line  ${text.trim()}';
}

/// 一组源码（相对路径 → 原文）。检查项只依赖它，因此可以被替换成假源码。
class SourceSet {
  final Map<String, String> _files;
  final List<String> missing;

  const SourceSet(this._files, this.missing);

  /// 统一成正斜杠，避免 Windows 路径把 `startsWith` / 比较弄坏。
  static String norm(String s) => p.normalize(s).replaceAll('\\', '/');

  factory SourceSet.fromMap(Map<String, String> files) =>
      SourceSet({for (final e in files.entries) norm(e.key): e.value}, const []);

  factory SourceSet.load(Iterable<String> paths) {
    final files = <String, String>{};
    final missing = <String>[];
    for (final rel in paths) {
      final f = File(rel);
      // 坑 1：用 existsSync()，不要用 exists()（后者是 Future<bool>）
      if (!f.existsSync()) {
        missing.add(norm(rel));
        continue;
      }
      files[norm(rel)] = f.readAsStringSync();
    }
    return SourceSet(files, missing);
  }

  factory SourceSet.loadTree(
    List<String> roots, {
    required List<String> extensions,
    List<String> excludePrefixes = const [],
  }) {
    final found = <String>[];
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final rel = norm(p.relative(entity.path));
        if (!extensions.any(rel.endsWith)) continue;
        if (excludePrefixes.any(rel.startsWith)) continue;
        found.add(rel);
      }
    }
    found.sort();
    return SourceSet.load(found);
  }

  Iterable<String> get paths => _files.keys;

  bool has(String rel) => _files.containsKey(norm(rel));

  String raw(String rel) => _files[norm(rel)] ?? '';

  /// 去注释后的代码（行号与原文对齐）。
  String code(String rel) => stripComments(raw(rel));

  /// 按行匹配。默认只匹配**代码**，但返回的 `text` 仍是原始行，便于人工核对。
  ///
  /// `dropStrings: true` 会额外把**字符串字面量的内容**也清空 ——
  /// 用于「必须出现在代码里，不能只是某个字符串/文档里被提到」的断言
  /// （例：D7 检查有没有真的调用 `.exists()`，而检查器自己的文案里就写着这个词）。
  List<SourceHit> hits(
    String rel,
    Pattern pattern, {
    bool codeOnly = true,
    bool dropStrings = false,
  }) {
    if (!has(rel)) return const [];
    var target = codeOnly ? code(rel) : raw(rel);
    if (codeOnly && dropStrings) target = stripStringLiterals(target);
    final rawLines = raw(rel).split('\n');
    final lines = target.split('\n');
    final out = <SourceHit>[];
    for (var i = 0; i < lines.length; i++) {
      if (pattern.allMatches(lines[i]).isEmpty) continue;
      out.add(SourceHit(norm(rel), i + 1, i < rawLines.length ? rawLines[i] : lines[i]));
    }
    return out;
  }

  /// 限定扫描范围（前缀过滤）。
  Iterable<String> pathsUnder(List<String> prefixes) =>
      paths.where((x) => prefixes.any(x.startsWith));

  /// 复制一份并把某个文件换成新内容（反向验证时用来注入违规）。
  SourceSet replace(String rel, String newRaw) {
    final copy = Map<String, String>.from(_files);
    copy[norm(rel)] = newRaw;
    return SourceSet(copy, missing);
  }

  SourceSet mutate(String rel, String Function(String raw) transform) =>
      replace(rel, transform(raw(rel)));
}

/// 去注释但**逐行保留换行**（行号必须与原文严格对齐）。
///
/// 字符串字面量的内容**保留**——字符串里出现禁则 token 仍属代码。
/// 这是启发式实现（不解析完整语法），对「结构契约断言」足够。
String stripComments(String src) {
  final out = StringBuffer();
  var i = 0;
  final n = src.length;

  while (i < n) {
    final c = src[i];

    // ---- 字符串字面量：原样保留（含换行，保住行号）----
    if (c == "'" || c == '"') {
      final isTriple = i + 2 < n && src[i + 1] == c && src[i + 2] == c;
      final delim = isTriple ? c * 3 : c;
      out.write(delim);
      var j = i + delim.length;
      while (j < n) {
        if (!isTriple && src[j] == r'\' && j + 1 < n) {
          out.write(src.substring(j, j + 2));
          j += 2;
          continue;
        }
        if (src.startsWith(delim, j)) {
          out.write(delim);
          j += delim.length;
          break;
        }
        out.write(src[j]);
        j++;
      }
      i = j;
      continue;
    }

    // ---- 行注释：丢掉内容，保留换行 ----
    if (c == '/' && i + 1 < n && src[i + 1] == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }

    // ---- 块注释：只保留其中的换行 ----
    if (c == '/' && i + 1 < n && src[i + 1] == '*') {
      i += 2;
      while (i < n && !(src[i] == '*' && i + 1 < n && src[i + 1] == '/')) {
        if (src[i] == '\n') out.write('\n');
        i++;
      }
      i = i < n ? i + 2 : i;
      continue;
    }

    out.write(c);
    i++;
  }

  return out.toString();
}

/// 把字符串字面量的**内容**清空（保留引号与换行，行号对齐）。
///
/// 与 [stripComments] 的区别：这里连字符串里的字符也不看。
/// 用于「必须真的调用，不能只是文案里提到」的断言 —— 例如 D7 要确认代码里
/// 没有 `.exists()`，而检查器自己的说明文字里就写着 `.exists()`，那是字符串不是调用。
String stripStringLiterals(String code) {
  final out = StringBuffer();
  var i = 0;
  final n = code.length;

  while (i < n) {
    final c = code[i];
    if (c == "'" || c == '"') {
      final isTriple = i + 2 < n && code[i + 1] == c && code[i + 2] == c;
      final delim = isTriple ? c * 3 : c;
      out.write(delim);
      var j = i + delim.length;
      while (j < n) {
        if (!isTriple && code[j] == r'\' && j + 1 < n) {
          j += 2;
          continue;
        }
        if (code.startsWith(delim, j)) {
          out.write(delim);
          j += delim.length;
          break;
        }
        // 只保留换行，其余字符丢弃 —— 行号必须与原文对齐
        if (code[j] == '\n') out.write('\n');
        j++;
      }
      i = j;
      continue;
    }
    out.write(c);
    i++;
  }

  return out.toString();
}

/// 单条定案的校验结果。
class DecisionResult {
  final String id;
  final String title;
  final String reference;
  final DecisionStatus status;

  /// 正向证据（计数、原文片段等），报告里会贴出来。
  final List<String> evidence;

  /// 违规点（文件:行 + 原文）。
  final List<SourceHit> violations;

  /// 只能人工核对的部分（如实标注，不冒充自动断言）。
  final String? limitation;

  const DecisionResult({
    required this.id,
    required this.title,
    required this.reference,
    required this.status,
    this.evidence = const [],
    this.violations = const [],
    this.limitation,
  });

  bool get isViolated => status == DecisionStatus.violated;

  /// 失败输出必须能直接指出「哪条定案没落地、在哪个文件」。
  String get failureMessage {
    final b = StringBuffer();
    b.writeln('「$id · $title」未落地');
    b.writeln('  依据：$reference');
    for (final v in violations) {
      b.writeln('  ✗ $v');
    }
    if (limitation != null) {
      b.writeln('  ⚠ 需人工核对：$limitation');
    }
    return b.toString().trimRight();
  }
}

/// 一条定案的可执行断言。
class DecisionCheck {
  final String id;
  final String title;
  final String reference;

  /// 这条断言**到底检查什么**（写进报告，不许只写「已加校验」）。
  final String checksWhat;

  final DecisionResult Function(SourceSet sources) run;

  const DecisionCheck({
    required this.id,
    required this.title,
    required this.reference,
    required this.checksWhat,
    required this.run,
  });
}

String _statusLabel(DecisionStatus s) => switch (s) {
      DecisionStatus.landed => '✅ 已落地',
      DecisionStatus.partial => '🟡 部分落地',
      DecisionStatus.violated => '❌ 未落地',
    };

/// 渲染可读报告（同时也落盘，避免「测试绿了就什么都看不到」）。
String renderReport(
  List<DecisionCheck> checks,
  List<DecisionResult> results,
  SourceSet sources, {
  required String generatedAt,
}) {
  final byId = {for (final r in results) r.id: r};
  final b = StringBuffer();
  b.writeln('# 定案 → 代码 · 落地校验报告');
  b.writeln();
  b.writeln('- 生成时间：$generatedAt');
  b.writeln('- 入口：`flutter test test/decisions/`（同一份断言也在全量 `flutter test` 里跑）');
  b.writeln('- 扫描：${sources.paths.length} 个文件'
      '（`android/app/src/main` + `lib` + `test/decisions`；扩展名 .kt/.dart/.xml）');
  if (sources.missing.isNotEmpty) {
    b.writeln('- ⚠ 缺失源文件 ${sources.missing.length} 个：${sources.missing.join('、')}');
  }
  b.writeln();
  b.writeln('| # | 定案 | 状态 | 这条断言检查什么 |');
  b.writeln('|---|---|---|---|');
  for (final c in checks) {
    final r = byId[c.id];
    b.writeln('| ${c.id} | ${c.title} | ${r == null ? '⬜ 未运行' : _statusLabel(r.status)} | ${c.checksWhat} |');
  }
  b.writeln();

  final violated = results.where((r) => r.isViolated).toList();
  b.writeln('## 未落地条目（${violated.length}）');
  if (violated.isEmpty) {
    b.writeln();
    b.writeln('无。全部 ${results.length} 条断言通过。');
  } else {
    for (final r in violated) {
      b.writeln();
      b.writeln('### ${r.id} · ${r.title}');
      b.writeln();
      b.writeln('依据：${r.reference}');
      b.writeln();
      b.writeln('```');
      for (final v in r.violations) {
        b.writeln(v.toString());
      }
      b.writeln('```');
    }
  }
  b.writeln();

  b.writeln('## 逐条证据');
  for (final c in checks) {
    final r = byId[c.id];
    b.writeln();
    b.writeln('### ${c.id} · ${c.title}');
    b.writeln();
    b.writeln('- 依据：${c.reference}');
    b.writeln('- 状态：${r == null ? '⬜ 未运行' : _statusLabel(r.status)}');
    if (r != null) {
      for (final e in r.evidence) {
        b.writeln('- $e');
      }
      if (r.limitation != null) {
        b.writeln('- ⚠ 只能人工核对：${r.limitation}');
      }
    }
  }
  b.writeln();

  b.writeln('## 反向验证（证明断言不是橡皮图章）');
  b.writeln();
  b.writeln('见 `test/decisions/decision_mechanism_selftest_test.dart`：');
  b.writeln('对每条定案注入一处**代表性违规**（如给 `AlarmService` 加一行 '
      '`intent.getStringExtra(EXTRA_RINGTONE)`），断言必须变成 ❌ 且报出文件名与行号。');
  b.writeln('若某条断言是空的，那个反向验证用例会红。');
  return b.toString();
}
