/// 轴对齐矩形（纯 Dart 实现）。
///
/// 排版引擎的 Domain 层刻意不依赖 Flutter 的 `dart:ui` Rect，
/// 保证零 Flutter 依赖、可独立单元测试。生产 UI 层渲染时再映射为 `Rect`。
class GeoRect {
  const GeoRect(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;

  /// 是否与「以 lineTop 为顶、高度 lineHeight 的水平带」在垂直方向相交。
  ///
  /// 用于判断某个排除区域（图片包围盒）是否影响当前排版行。
  bool overlapsBand(double lineTop, double lineHeight) {
    return y < lineTop + lineHeight && y + height > lineTop;
  }

  @override
  String toString() => 'GeoRect($x, $y, $width, $height)';
}
