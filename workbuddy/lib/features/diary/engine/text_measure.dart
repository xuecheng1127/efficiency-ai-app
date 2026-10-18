/// 文本测量抽象：排版引擎不依赖 Flutter 的 `TextPainter`，
/// 便于纯 Dart 单元测试。
///
/// PoC 使用 [ApproxTextMeasurer] 近似测量；生产环境应注入基于
/// `TextPainter` 的精确实现，以获得真实字形宽度。
abstract class TextMeasurer {
  /// 单个字符的宽度。
  double charWidth(String char);
}

/// 近似测量器：中文全角字符宽 = fontSize，ASCII 半角 ≈ 0.5 × fontSize。
///
/// 仅用于 PoC 与单元测试，验证排版算法正确性；精度不用于生产。
class ApproxTextMeasurer implements TextMeasurer {
  ApproxTextMeasurer({required this.fontSize});

  final double fontSize;

  @override
  double charWidth(String char) {
    if (char.isEmpty) return 0;
    final code = char.codeUnitAt(0);
    return _isFullWidth(code) ? fontSize : fontSize * 0.5;
  }

  /// 粗略判断是否为全角字符（CJK 汉字 / CJK 标点 / 全角符号）。
  static bool _isFullWidth(int code) {
    return (code >= 0x4E00 && code <= 0x9FFF) || // 基本汉字
        (code >= 0x3000 && code <= 0x303F) || // CJK 标点
        (code >= 0xFF00 && code <= 0xFFEF); // 全角字符
  }
}
