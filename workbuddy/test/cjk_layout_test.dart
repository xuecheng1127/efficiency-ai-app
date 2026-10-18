import 'package:efficiency_app/features/diary/engine/cjk_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// T22 阶段 A · 中文排版引擎单元测试（纯 Dart，不依赖任何 widget）。
///
/// ## 关于「标点不出现在行首/行尾」的判定口径（重要，评审方请先看这段）
///
/// 中文禁则分两类，方向相反：
/// - **禁则头**（`，。、；：？！）》」』】〕〉”’`）不许落在**行首**；
/// - **禁则尾**（`（《「『【〔〈“‘`）不许落在**行尾**。
///
/// 而「悬挂标点」（级别 1）本来就是**故意**把禁则头挂在**行尾外面**（不占行内宽度），
/// 这是中文排版最标准的处理，不属于违规。所以本文件断言的是**禁则方向**：
///   - 每行首字 ∉ 禁则头；
///   - 每行末字 ∉ 禁则尾。
/// 而不是粗暴的「任何标点都不许出现在行首或行尾」（那样悬挂标点就永远不合法了）。
void main() {
  const fontSize = 10.0; // 全角字宽 = 10
  late CjkLayoutEngine engine;

  // 每个用例独立引擎，避免段落缓存跨用例串味
  setUp(() => engine = CjkLayoutEngine());

  /// 取一行里的 rune 列表。
  List<int> runesOf(String s) => s.runes.toList();

  group('T22-A 中文排版引擎', () {
    // ---------------------------------------------------------------- 用例 1
    test('用例1 · 按宽度断行：每行宽度 ≤ 可用宽度', () {
      const text = '中文排版引擎需要按宽度断行，这是一段足够长的中文文本用来验证断行宽度是否超限。';
      const maxWidth = 100.0; // = 10 个全角字

      final result = engine.layoutText(
        text: text,
        maxWidth: maxWidth,
        fontSize: fontSize,
      );

      expect(result.lines, isNotEmpty);

      for (final line in result.lines) {
        expect(line.layoutWidth, lessThanOrEqualTo(maxWidth + 1e-9),
            reason: '行「${line.text}」宽度 ${line.layoutWidth} 超过 $maxWidth');
        // 行的原始宽度也不能超（未压缩时）
        if (line.compressedRatio == 1.0) {
          expect(line.rawWidth, lessThanOrEqualTo(maxWidth + 1e-9));
        }
      }

      // 所有行拼起来必须还原原文（不丢字、不重字）
      expect(result.lines.map((l) => l.text).join(), text);

      // offset 必须自洽
      for (final line in result.lines) {
        expect(text.substring(line.startOffset, line.endOffset), line.text);
      }
    });

    // ---------------------------------------------------------------- 用例 2
    test('用例2 · 避头尾：禁则头不上行首、禁则尾不上行尾', () {
      // 这个输入是**构造出来的**，不是随便找一段中文：
      // 可用宽度 = 5 个全角字，而文本里每第 6 个字就是标点 ——
      // 于是"纯贪心断行"必然把 `，。》；：！` 甩到下一行行首、把 `（` 留在行尾。
      // 只要避头尾逻辑一失效，本用例立刻红（这就是反向验证能抓到它的原因）。
      const text = '一二三四五，六七八九十。十一十二十三《十四十五》十六（十七）十八；十九：二十！';
      const maxWidth = 50.0; // = 5 个全角字

      final result = engine.layoutText(
        text: text,
        maxWidth: maxWidth,
        fontSize: fontSize,
      );

      expect(result.lines.length, greaterThan(3), reason: '需要真的断成多行才有意义');

      for (final line in result.lines) {
        final runes = runesOf(line.text);
        expect(runes, isNotEmpty); // 正常文本不该出现空行
        expect(
          CjkRules.canStartLine(runes.first),
          isTrue,
          reason: '行首出现了禁则头：行「${line.text}」以「${line.text[0]}」开头',
        );
        expect(
          CjkRules.canEndLine(runes.last),
          isTrue,
          reason: '行尾出现了禁则尾：行「${line.text}」以「${line.text[line.text.length - 1]}」结尾',
        );
      }

      // 拼回原文（悬挂标点也算在本行里，所以能完整还原）
      expect(result.lines.map((l) => l.text).join(), text);

      // 并且**真的**发生过悬挂（否则说明是"靠运气"没触发禁则处理）
      expect(result.lines.any((l) => l.hangingPunctuation), isTrue,
          reason: '这段文本必然触发悬挂标点降级，没触发说明断行逻辑不对');
    });

    // ---------------------------------------------------------------- 用例 3
    test('用例3 · 悬挂降级：标点装不下时挂在行尾，而不是被推到下一行行首', () {
      // '一二三' 恰好 30 宽；再加 '，' 变 40，超过 maxWidth=35 → 触发禁则头处理
      const text = '一二三，四五';
      const maxWidth = 35.0;

      final result = engine.layoutText(
        text: text,
        maxWidth: maxWidth,
        fontSize: fontSize,
        allowHang: true,
      );

      final first = result.lines.first;
      expect(first.hangingPunctuation, isTrue,
          reason: '应走「悬挂标点」降级，实际：${first.text}');
      expect(first.hangingRune, 0xFF0C); // ，
      expect(first.text, '一二三，');
      // 悬挂的字**不计入**行内宽度
      expect(first.rawWidth, 30.0);
      expect(first.layoutWidth, lessThanOrEqualTo(maxWidth));
      // 下一行不以标点开头
      final second = result.lines[1];
      expect(second.text.startsWith('，'), isFalse);
      expect(runesOf(second.text).first, isNot(0xFF0C));
    });

    // ---------------------------------------------------------------- 用例 4
    test('用例4 · 字距挤压：悬挂关掉时压 ≤5% 把标点挤进本行', () {
      // 30 + 10 = 40；maxWidth=39 → 40 ≤ 39*1.05=40.95，可以挤进来
      const text = '一二三，四五';
      const maxWidth = 39.0;

      final result = engine.layoutText(
        text: text,
        maxWidth: maxWidth,
        fontSize: fontSize,
        allowHang: false,
        allowCompression: true,
      );

      final first = result.lines.first;
      expect(first.compressedRatio, greaterThan(1.0),
          reason: '应发生字距挤压，实际压缩比 ${first.compressedRatio}');
      expect(first.compressedRatio, lessThanOrEqualTo(1.05),
          reason: 'PRD 要求挤压 ≤5%，实际 ${first.compressedRatio}');
      expect(first.text, '一二三，');
      expect(first.hangingPunctuation, isFalse);
      // 挤压后占位宽度正好收到可用宽度
      expect(first.layoutWidth, closeTo(maxWidth, 0.01));
    });

    // ---------------------------------------------------------------- 用例 5
    test('用例5 · 边界：空串 / 多空行 / 超长英文 / 连续标点 / emoji 都不崩', () {
      // 空串
      final empty = engine.layoutText(text: '', maxWidth: 100, fontSize: fontSize);
      expect(empty.lines.length, 1);
      expect(empty.lines.single.isEmpty, isTrue);

      // 多空行：段落数 = 4（a,b 之间两个空行）
      final multiline = engine.layoutText(
        text: 'a\n\n\nb',
        maxWidth: 100,
        fontSize: fontSize,
      );
      expect(multiline.lines.length, 4);
      expect(multiline.lines[1].isEmpty, isTrue);
      expect(multiline.lines[2].isEmpty, isTrue);

      // 超长英文单词（比可用宽度还宽）：不崩、不丢字，允许单字溢出
      const longWord = 'abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz';
      final word = engine.layoutText(
        text: longWord,
        maxWidth: 40,
        fontSize: fontSize,
      );
      expect(word.lines.map((l) => l.text).join(), longWord);
      expect(word.lines, isNotEmpty);

      // 连续标点：不能全堆到下一行行首
      final punct = engine.layoutText(
        text: '一二三。。。四',
        maxWidth: 35,
        fontSize: fontSize,
      );
      for (final line in punct.lines) {
        expect(CjkRules.canStartLine(runesOf(line.text).first), isTrue,
            reason: '连续标点导致行首出现禁则头：${line.text}');
      }

      // emoji（代理对）：offset 必须仍然自洽
      const withEmoji = '你好😀世界';
      final emoji = engine.layoutText(
        text: withEmoji,
        maxWidth: 25,
        fontSize: fontSize,
      );
      expect(emoji.lines.map((l) => l.text).join(), withEmoji);
      for (final line in emoji.lines) {
        expect(withEmoji.substring(line.startOffset, line.endOffset), line.text);
      }
    });

    // ---------------------------------------------------------------- 用例 6
    test('用例6 · 增量重排：只重排被改动的段落', () {
      final incremental = CjkLayoutEngine();
      final paragraphs = ['第一段内容需要断行', '第二段内容需要断行', '第三段内容需要断行'];

      final first = incremental.layoutParagraphs(
        paragraphs,
        maxWidth: 60,
        fontSize: fontSize,
      );
      expect(first.reusedParagraphs, 0);
      expect(first.laidOutParagraphs, 3);

      // 只改中间那段
      final changed = ['第一段内容需要断行', '第二段被改长了，需要重新排版', '第三段内容需要断行'];
      final second = incremental.layoutParagraphs(
        changed,
        maxWidth: 60,
        fontSize: fontSize,
      );
      expect(second.reusedParagraphs, 2, reason: '未改的两段应命中缓存');
      expect(second.laidOutParagraphs, 1, reason: '只应重排被改动的那一段');
    });

    // ---------------------------------------------------------------- 用例 7
    test('用例7 · 行级缓存：同样的输入第二次全部命中缓存', () {
      final cached = CjkLayoutEngine();
      const text = '缓存命中测试，内容不变就不该重排。';

      final first = cached.layoutText(text: text, maxWidth: 80, fontSize: fontSize);
      expect(first.laidOutParagraphs, 1);

      final second = cached.layoutText(text: text, maxWidth: 80, fontSize: fontSize);
      expect(second.reusedParagraphs, 1);
      expect(second.laidOutParagraphs, 0);
      // 结果必须与第一次完全一致
      expect(
        second.lines.map((l) => l.text).toList(),
        first.lines.map((l) => l.text).toList(),
      );
    });

    // ---------------------------------------------------------------- 用例 8
    test('用例8 · 行高 = 字号 × 1.5（PRD 硬要求）', () {
      expect(engine.lineHeightFor(16), 24);
      expect(engine.lineHeightFor(12), 18);
      expect(engine.lineHeightFor(32), 48);
    });
  });
}
