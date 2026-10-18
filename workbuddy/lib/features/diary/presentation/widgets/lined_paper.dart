import 'package:flutter/material.dart';

/// 横线本背景：按**行高**画极浅的横线（行高由排版引擎的 `lineHeightFor` 给出）。
///
/// 为什么要自己画而不是用背景图：行高会随字号变（字号 × 1.5），
/// 背景图无法跟着缩放，画出来的线会和文字错位。
class LinedPaperPainter extends CustomPainter {
  LinedPaperPainter({
    required this.lineHeight,
    required this.lineColor,
    required this.topOffset,
    required this.horizontalPadding,
  });

  final double lineHeight;
  final Color lineColor;

  /// 第一条线的 y（通常等于编辑区的上内边距，让文字坐在线上）
  final double topOffset;
  final double horizontalPadding;

  @override
  void paint(Canvas canvas, Size size) {
    if (lineHeight <= 0) return;
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1
      ..isAntiAlias = false;
    var y = topOffset;
    while (y < size.height) {
      canvas.drawLine(
        Offset(horizontalPadding, y),
        Offset(size.width - horizontalPadding, y),
        paint,
      );
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant LinedPaperPainter oldDelegate) {
    return oldDelegate.lineHeight != lineHeight ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.topOffset != topOffset ||
        oldDelegate.horizontalPadding != horizontalPadding;
  }
}
