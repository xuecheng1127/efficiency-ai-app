import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/features/diary/engine/flow_layout.dart';
import 'package:efficiency_app/features/diary/engine/geo.dart';
import 'package:efficiency_app/features/diary/engine/text_measure.dart';

void main() {
  group('FlowLayoutEngine 文字绕排', () {
    // 中文全角每字 10 宽，行高 15
    final measurer = ApproxTextMeasurer(fontSize: 10);

    test('无排除区域：普通流式排版', () {
      final engine = FlowLayoutEngine(measurer: measurer, lineHeight: 15);
      final result = engine.layout(text: '一二三四五六七八', pageWidth: 40);

      expect(result.fragments.length, 2, reason: '每行 4 字，共 2 行');
      expect(result.height, 30, reason: '2 行 × 15 行高');
      expect(result.fragments.first.rect.width, 40, reason: '首行满宽');
    });

    test('中间图片：文字绕到图片左右两侧', () {
      final engine = FlowLayoutEngine(measurer: measurer, lineHeight: 15);
      // 图片占据第二行中间 x=20..40（含安全边距后的包围盒）
      final exclusion = GeoRect(20, 15, 20, 15);

      final result = engine.layout(
        text: '一二三四五六七八九十',
        pageWidth: 60,
        exclusions: [exclusion],
      );

      // 第二行被图片切成左、右两段
      final secondRow = result.fragments.where((f) => f.rect.y == 15).toList();
      expect(secondRow.length, 2, reason: '第二行应有左右两段');
      expect(secondRow[0].text, '七八', reason: '图片左侧段落');
      expect(secondRow[1].text, '九十', reason: '图片右侧段落');
      expect(secondRow[1].rect.x, 40, reason: '右段从图片右边界开始');

      // 所有片段均不与排除区域重叠
      for (final f in result.fragments) {
        final overlap =
            f.rect.x < exclusion.right &&
            f.rect.right > exclusion.x &&
            f.rect.y < exclusion.bottom &&
            f.rect.bottom > exclusion.y;
        expect(overlap, isFalse, reason: '片段 $f 不应与图片重叠');
      }
    });

    test('图片占满整行：该行跳过，文字续排到下一行', () {
      final engine = FlowLayoutEngine(measurer: measurer, lineHeight: 15);
      // 图片占满第二行整个宽度
      final exclusion = GeoRect(0, 15, 60, 15);

      final result = engine.layout(
        text: '一二三四五六七八九十',
        pageWidth: 60,
        exclusions: [exclusion],
      );

      // 第二行被图片占满，文字应从第一行直接跳到第三行
      final hasSecondRowText = result.fragments.any((f) => f.rect.y == 15);
      expect(hasSecondRowText, isFalse, reason: '第二行不应有文字');
      expect(
        result.fragments.any((f) => f.rect.y == 30),
        isTrue,
        reason: '文字应续排到第三行',
      );
    });
  });
}
