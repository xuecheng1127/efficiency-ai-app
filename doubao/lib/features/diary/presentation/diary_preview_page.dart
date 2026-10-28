import 'package:flutter/material.dart';

import '../engine/cjk_layout.dart';

/// 日记预览页（只读）
///
/// 用 CJK 避头尾引擎逐行排版，行高 = 字号 × 1.5，
/// 横线本模式下横线与文字行对齐。
class DiaryPreviewPage extends StatelessWidget {
  final String title;
  final String content;
  final double fontSize;
  final bool lined;

  const DiaryPreviewPage({
    super.key,
    required this.title,
    required this.content,
    this.fontSize = 16.0,
    this.lined = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.of(context).padding +
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
        final maxWidth = constraints.maxWidth - padding.horizontal;
        return SingleChildScrollView(
          padding: padding,
          child: _PreviewBody(
            content: content,
            fontSize: fontSize,
            lined: lined,
            maxWidth: maxWidth,
          ),
        );
      },
    );
  }
}

class _PreviewBody extends StatelessWidget {
  final String content;
  final double fontSize;
  final bool lined;
  final double maxWidth;

  const _PreviewBody({
    required this.content,
    required this.fontSize,
    required this.lined,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final lineHeight = fontSize * 1.5;
    final style = TextStyle(fontSize: fontSize, height: 1.0);

    // 度量一个 CJK 字符宽度
    final measureTp = TextPainter(
      text: TextSpan(text: '汉', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final charW = measureTp.width;

    // 临时：短内容用测试文本
    final effectiveContent = content.length < 20
        ? '今天下午去了图书馆，借了三本书：《数据结构》《算法导论》《操作系统概念》。回来的路上顺便买了点水果：苹果、香蕉、橘子，还有酸奶。晚上打算先看第一章（大概五十页），如果时间够的话再看第二章。明天早上要去跑步（六点半），希望能坚持下来。'
        : content;

    // 按 \n 分段，每段用 CjkLayout 断行
    final paragraphs = effectiveContent.split('\n');
    final allLines = <String>[];
    for (final p in paragraphs) {
      if (p.isEmpty) {
        allLines.add('');
        continue;
      }
      final rendered = CjkLayout.layout(
        p,
        LayoutInput(maxWidth: maxWidth, measure: (_) => charW),
      );
      for (final line in rendered) {
        allLines.add(line.chars.map((c) => c.char).join());
      }
    }

    final paintHeight = allLines.length * lineHeight;
    return CustomPaint(
      size: Size(maxWidth, paintHeight),
      painter: _PreviewPainter(
        lines: allLines,
        lineHeight: lineHeight,
        fontSize: fontSize,
        lined: lined,
        style: style,
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final List<String> lines;
  final double lineHeight;
  final double fontSize;
  final bool lined;
  final TextStyle style;

  _PreviewPainter({
    required this.lines,
    required this.lineHeight,
    required this.fontSize,
    required this.lined,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;

    for (var i = 0; i < lines.length; i++) {
      final y = i * lineHeight;

      // 横线本：画线
      if (lined) {
        canvas.drawLine(
          Offset(0, y + lineHeight - fontSize * 0.2),
          Offset(size.width, y + lineHeight - fontSize * 0.2),
          linePaint,
        );
      }

      // 文字：每行单独 TextPainter
      final tp = TextPainter(
        text: TextSpan(text: lines[i], style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width);
      final ty = y + (lineHeight - tp.height) / 2;
      tp.paint(canvas, Offset(0, ty));
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) =>
      oldDelegate.lines != lines ||
      oldDelegate.lineHeight != lineHeight ||
      oldDelegate.lined != lined;
}
