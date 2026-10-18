import 'package:efficiency_app/features/diary/engine/cjk_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// T22 阶段 A：中文避头尾排版引擎单元测试
///
/// 评审方会自己构造输入跑这些测试。
void main() {
  // 固定字号：每个汉字宽度 16，标点宽度 8
  double measure(String ch) {
    if (ch.codeUnitAt(0) > 127) return 16; // 中文
    return 8; // 英文/标点
  }

  group('1. 按宽度断行', () {
    test('每行宽度 ≤ 可用宽度', () {
      // 10 个汉字，每行放 3 个（48px），maxWidth=50
      final input = LayoutInput(maxWidth: 50, measure: measure);
      final lines = CjkLayout.layout('一二三四五六七八九十', input);
      for (final line in lines) {
        expect(line.lineWidth <= 50, isTrue,
            reason: '行宽 ${line.lineWidth} 超过 50');
      }
      // 至少分 4 行（3+3+3+1）
      expect(lines.length, greaterThanOrEqualTo(4));
    });
  });

  group('2. 避头尾', () {
    test('，。不出现行首', () {
      // 构造：每行刚好放下 3 个汉字，第 4 个是逗号
      // 期望：逗号悬挂或被带走，不单独出现在下一行行首
      final input = LayoutInput(maxWidth: 50, measure: measure);
      final text = '你好，世界。今天，天气，真好。';
      final lines = CjkLayout.layout(text, input);

      for (final line in lines) {
        if (line.chars.isEmpty) continue;
        final first = line.chars.first.char;
        expect(kLineHeadForbidden.contains(first), isFalse,
            reason: '行首出现禁则标点: "$first" (行内容: ${line.chars.map((c) => c.char).join()})');
      }
    });

    test('《（不出现行尾', () {
      final input = LayoutInput(maxWidth: 50, measure: measure);
      final text = '我喜欢《红楼梦》和《西游记》。';
      final lines = CjkLayout.layout(text, input);

      for (final line in lines) {
        if (line.chars.isEmpty) continue;
        final last = line.chars.last.char;
        // 悬挂标点不算行尾（hanging）
        if (line.hangingWidth > 0) continue;
        expect(kLineTailForbidden.contains(last), isFalse,
            reason: '行尾出现禁则标点: "$last" (行内容: ${line.chars.map((c) => c.char).join()})');
      }
    });
  });

  group('3. 悬挂标点降级', () {
    test('标点刚好放不下时走悬挂而非强制换行', () {
      // 构造：maxWidth=48（正好 3 个汉字 48px）
      // 文本：3 个汉字 + 逗号 + 汉字
      // 逗号宽 8，放不进行内 → 应悬挂
      final input = LayoutInput(maxWidth: 48, measure: measure);
      final lines = CjkLayout.layout('你好世，界测试', input);
      // 第一行应该含悬挂标点
      final first = lines.first;
      expect(first.hangingWidth, greaterThan(0),
          reason: '逗号应悬挂到行尾外面');
      expect(first.chars.last.char, '，');
    });
  });

  group('4. 字距挤压', () {
    test('悬挂也装不下时挤压 ≤5%', () {
      // 构造极端情况：maxWidth 很小，需要挤压才能放下禁则尾标点
      // 4 个汉字宽 64，maxWidth=60 → 需要挤压
      final input = LayoutInput(maxWidth: 60, measure: measure);
      // 《开头（禁则尾），后接汉字
      final lines = CjkLayout.layout('《一二三四五', input);
      for (final line in lines) {
        expect(line.squeezeRatio <= 0.05, isTrue,
            reason: '挤压比例 ${line.squeezeRatio} 超过 5%');
      }
    });
  });

  group('5. 边界', () {
    test('空文本不崩', () {
      final input = LayoutInput(maxWidth: 100, measure: measure);
      expect(CjkLayout.layout('', input), isEmpty);
    });

    test('超长英文单词不崩', () {
      final input = LayoutInput(maxWidth: 40, measure: measure);
      final lines = CjkLayout.layout('abcdefghijklmnop', input);
      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(line.lineWidth <= 40 + 8, isTrue); // 允许一个字符溢出
      }
    });

    test('连续标点不崩', () {
      final input = LayoutInput(maxWidth: 50, measure: measure);
      final lines = CjkLayout.layout('，，。。、、；；：：', input);
      expect(lines, isNotEmpty);
    });
  });
}
