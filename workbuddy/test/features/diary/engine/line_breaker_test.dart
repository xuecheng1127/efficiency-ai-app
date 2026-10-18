import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/features/diary/engine/line_breaker.dart';
import 'package:efficiency_app/features/diary/engine/text_measure.dart';

void main() {
  group('LineBreaker 断行 + 中文标点避头尾', () {
    // 中文全角每字 10 宽
    final measurer = ApproxTextMeasurer(fontSize: 10);

    test('按宽度断行（中文全角）', () {
      final breaker = LineBreaker(measurer: measurer, maxWidth: 40);
      // 每行 4 字
      expect(breaker.breakLines('一二三四五六七八'), ['一二三四', '五六七八']);
    });

    test('避头：句号不落到下一行行首，而是悬挂到本行行尾', () {
      final breaker = LineBreaker(measurer: measurer, maxWidth: 40);
      final lines = breaker.breakLines('一二三四。五六');

      expect(lines.first.endsWith('。'), isTrue, reason: '句号应悬挂到第一行行尾');
      expect(lines[1].startsWith('。'), isFalse, reason: '下一行行首不应是句号');
    });

    test('避尾：左括号《不留在行尾，而是移到下一行', () {
      final breaker = LineBreaker(measurer: measurer, maxWidth: 30);
      final lines = breaker.breakLines('一二《三四');

      for (final line in lines) {
        expect(line.endsWith('《'), isFalse, reason: '行尾不应是左括号');
      }
      // 左括号被移到第二行行首
      expect(lines[1].startsWith('《'), isTrue);
    });
  });
}
