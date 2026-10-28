import 'dart:ui' as ui;

import 'package:efficiency_app/features/diary/engine/cjk_layout.dart';
import 'package:efficiency_app/features/diary/presentation/widgets/cjk_preview_painter.dart';
import 'package:efficiency_app/features/diary/presentation/widgets/text_painter_measurer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验收用的标点密集段落（inbox 原文，一字不差）。
const String acceptanceText =
    '今天下午去了图书馆，借了三本书：《数据结构》《算法导论》《操作系统概念》。'
    '回来的路上顺便买了点水果：苹果、香蕉、橘子，还有酸奶。'
    '晚上打算先看第一章（大概五十页），如果时间够的话再看第二章。'
    '明天早上要去跑步（六点半），希望能坚持下来。';

/// 行首禁忌标点（少一个都算不合格）。
const List<String> forbiddenLineStart = [
  '，',
  '。',
  '：',
  '、',
  '》',
  '）',
  '；',
  '？',
  '！',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 与 DiaryPreviewPage 完全一致的几何：360dp 宽屏、16 内边距、字号 16、
  // 右侧再让出一个全角给悬挂标点。
  const double fontSize = 16;
  const double screenWidth = 360;
  const double leftPadding = 16;
  const double maxWidth = screenWidth - leftPadding * 2 - fontSize; // 312
  const double lineHeight = fontSize * 1.5; // 24

  CjkLayoutEngine newEngine() => CjkLayoutEngine(
    measurer: TextPainterGlyphMeasurer(baseStyle: const TextStyle()),
    lineHeightRatio: 1.5,
  );

  group('预览页排版（引擎 + TextPainter 真实字形度量）', () {
    test('验收段落：≥6 行，行首无标点，全文不丢字不重字', () {
      final result = newEngine().layoutText(
        text: acceptanceText,
        maxWidth: maxWidth,
        fontSize: fontSize,
      );

      expect(
        result.lines.length,
        greaterThanOrEqualTo(6),
        reason: '301 字的段落按 312 宽排版，至少该有 6 行（实际 ${result.lines.length}）',
      );

      for (final line in result.lines) {
        final head = String.fromCharCode(line.text.runes.first);
        expect(
          forbiddenLineStart.contains(head),
          isFalse,
          reason: '行首出现了禁则标点「$head」→ ${line.text}',
        );
      }

      expect(
        result.lines.map((l) => l.text).join(),
        acceptanceText,
        reason: '把所有行拼回去必须与原文逐字相等（悬挂标点不能吞字/重字）',
      );
    });

    test('每行实际占宽 ≤ 可用宽度（悬挂/挤压之后仍然成立）', () {
      final result = newEngine().layoutText(
        text: acceptanceText,
        maxWidth: maxWidth,
        fontSize: fontSize,
      );

      for (final line in result.lines) {
        expect(
          line.rawWidth,
          lessThanOrEqualTo(maxWidth + 0.01),
          reason: '行内字宽之和超了：${line.text}',
        );
        // 挤压上限 5%，所以 layoutWidth 最多到 maxWidth * 1.05，不能再多
        expect(
          line.layoutWidth,
          lessThanOrEqualTo(maxWidth * 1.05 + 0.01),
          reason: '行占宽超了：${line.text}',
        );
      }
    });

    test('每行 TextPainter 高度 == 行高（这是「行与行不重叠」的充要条件）', () {
      final result = newEngine().layoutText(
        text: acceptanceText,
        maxWidth: maxWidth,
        fontSize: fontSize,
      );
      const style = TextStyle(
        fontSize: fontSize,
        height: 1.5,
        textBaseline: TextBaseline.alphabetic,
      );

      for (final line in result.lines) {
        final painter = TextPainter(
          text: TextSpan(text: line.text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
        )..layout();
        expect(
          painter.height,
          closeTo(lineHeight, 0.01),
          reason: '单行高度必须正好等于行高，否则相邻行会叠在一起：${line.text}',
        );
        // 每行单独 layout 且不给 maxWidth，框架没有机会二次折行
        expect(painter.computeLineMetrics().length, 1);
        painter.dispose();
      }
    });

    test('增量重排：同一次 build 重复调用，第二次全部命中段落缓存', () {
      final engine = newEngine();
      final first = engine.layoutText(
        text: acceptanceText,
        maxWidth: maxWidth,
        fontSize: fontSize,
      );
      expect(first.laidOutParagraphs, greaterThan(0));

      final second = engine.layoutText(
        text: acceptanceText,
        maxWidth: maxWidth,
        fontSize: fontSize,
      );
      expect(second.laidOutParagraphs, 0, reason: '文本/宽度/字号都没变，不该重排');
      expect(second.reusedParagraphs, first.laidOutParagraphs);
      expect(second.lines.length, first.lines.length);
    });

    test('1000 字上限：首次排版 < 300ms（含逐字度量建缓存）', () {
      final buffer = StringBuffer();
      while (buffer.length < 1000) {
        buffer.write(acceptanceText);
      }
      final text = buffer.toString().substring(0, 1000);

      final watch = Stopwatch()..start();
      final result = newEngine().layoutText(
        text: text,
        maxWidth: maxWidth,
        fontSize: fontSize,
      );
      watch.stop();

      expect(result.lines.length, greaterThan(30));
      expect(
        watch.elapsedMilliseconds,
        lessThan(300),
        reason: '1000 字首次排版耗时 ${watch.elapsedMilliseconds}ms，超过 300ms 预算',
      );
    });

    test('painter 能把 6 行以上画到画布上且不抛异常', () {
      final result = newEngine().layoutText(
        text: acceptanceText,
        maxWidth: maxWidth,
        fontSize: fontSize,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      CjkPreviewPainter(
        lines: result.lines,
        textStyle: const TextStyle(
          fontSize: fontSize,
          height: 1.5,
          color: Color(0xFF000000),
        ),
        lineHeight: lineHeight,
        left: leftPadding,
        right: screenWidth - leftPadding,
        topPadding: 8,
        lined: true,
        lineColor: const Color(0xFFE0E0E0),
      ).paint(canvas, const Size(screenWidth, 400));

      final picture = recorder.endRecording();
      expect(picture.approximateBytesUsed, greaterThan(0));
      picture.dispose();
    });
  });
}
