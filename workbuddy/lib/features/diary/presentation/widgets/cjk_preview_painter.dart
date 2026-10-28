import 'package:flutter/material.dart';

import '../../engine/cjk_layout.dart';

/// 把 `CjkLayoutEngine` 算出来的行**逐行**画到画布上。
///
/// ## 为什么是 CustomPaint + 每行一个 TextPainter
///
/// `TextField` 的换行由框架内部完成，没法接管 —— 所以避头尾必须在**只读渲染**里
/// 才能生效。而只读渲染如果拿 `Text` 控件逐行摆，就退回到「框架再换一次行」：
/// 引擎算的是 A 断法，`Text` 会按自己的 B 断法再换，两边不一致就会出现
/// 「行尾留一大截」或「右边缘溢出」。所以这里：
///
/// - 每行 **new 一个 TextPainter，只 layout 这一行的字符串**，且 `layout()` 不给
///   `maxWidth`（= 无限宽），框架没有机会再折行；
/// - 行位置由**画布坐标**决定（`topPadding + i * lineHeight`），不用
///   `SizedBox`/`Align`/`Column` 堆 —— 容器布局会按自己的约束裁剪或压缩子项，
///   这就是上一版「行与行叠在一起」的根因。
///
/// ## 悬挂标点怎么不飞出屏幕
///
/// 行文本里含悬挂标点（引擎的 `hangingPunctuation`），它的宽度**不计入**
/// `layoutWidth`。调用方因此把排版宽度留出一个全角（见 `DiaryPreviewPage` 的
/// `maxLineWidth`），悬挂的那个标点正好落在右侧留白里。
class CjkPreviewPainter extends CustomPainter {
  CjkPreviewPainter({
    required this.lines,
    required this.textStyle,
    required this.lineHeight,
    required this.left,
    required this.right,
    required this.topPadding,
    required this.lined,
    required this.lineColor,
  });

  /// 引擎输出的行（含空行，空行也要占一个行位，保持纵向节奏）。
  final List<RenderedLine> lines;

  /// 行文本样式。**必须**与 `TextPainterGlyphMeasurer.baseStyle + fontSize` 一致。
  final TextStyle textStyle;

  /// 行高 = 字号 × 1.5（与引擎的 `lineHeightFor` 同源）。
  final double lineHeight;

  /// 文字左边界（= 页面内边距）。
  final double left;

  /// 横线的右端（不含悬挂区）。
  final double right;

  /// 首行行位之前的留白。
  final double topPadding;

  /// 横线本模式才画横线。
  final bool lined;

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (lined) {
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = 1
        ..isAntiAlias = false;
      // 横线画在每个行位的**底部**，与编辑页的 LinedPaperPainter 同一套坐标，
      // 所以同一个 fontSize 下预览页与编辑页的线是能够对齐的。
      var y = topPadding + lineHeight;
      while (y < size.height) {
        canvas.drawLine(Offset(left, y), Offset(right, y), paint);
        y += lineHeight;
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.text.isEmpty) continue; // 空行：占位但不画
      final painter = TextPainter(
        text: TextSpan(text: line.text, style: textStyle),
        textDirection: TextDirection.ltr,
        // 单行 + 无限宽：框架不会再折行，断行结果 100% 由引擎决定。
        maxLines: 1,
        textScaler: TextScaler.noScaling,
      )..layout();
      painter.paint(canvas, Offset(left, topPadding + i * lineHeight));
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant CjkPreviewPainter oldDelegate) {
    return !identical(oldDelegate.lines, lines) ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.left != left ||
        oldDelegate.right != right ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.lined != lined ||
        oldDelegate.lineColor != lineColor;
  }
}
