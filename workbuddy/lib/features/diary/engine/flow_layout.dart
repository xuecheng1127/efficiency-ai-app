import 'geo.dart';
import 'line_breaker.dart';
import 'text_measure.dart';

/// 排除区域：图片包围盒（已含 8dp 安全边距），文字需绕开它。
typedef ExclusionArea = GeoRect;

/// 排版结果：一个文本片段（渲染矩形 + 文本内容）。
class TextFragment {
  const TextFragment({required this.rect, required this.text});

  final GeoRect rect;
  final String text;

  @override
  String toString() => 'TextFragment($text @ $rect)';
}

/// 文字绕排引擎：行扫描 + 排除区域分段渲染。
///
/// 核心思路（「排除区域表 + 分段渲染」，对应需求文档排版引擎方案）：
/// 逐行排版，每行先求出与当前行垂直相交的排除区域，据此把整行切成若干
/// 「可用水平区间」，再在每个区间内贪心排字（复用标点避头尾），
/// 从而让文字自然绕开图片，而非简单绝对定位。
class FlowLayoutEngine {
  FlowLayoutEngine({required this.measurer, required this.lineHeight});

  final TextMeasurer measurer;

  /// 行高（字号 × 1.5，见需求文档）。
  final double lineHeight;

  /// 排版一段文本，返回文本片段列表与排版总高度。
  ({List<TextFragment> fragments, double height}) layout({
    required String text,
    required double pageWidth,
    List<ExclusionArea> exclusions = const [],
  }) {
    final fragments = <TextFragment>[];
    final runes = text.runes.toList();
    var runeIndex = 0;
    var y = 0.0;

    while (runeIndex < runes.length) {
      final line = _layoutLine(runes, runeIndex, y, pageWidth, exclusions);

      // 该行无可用区间（整行被排除区域占满），直接跳到下一行
      if (line.fragments.isEmpty) {
        y += lineHeight;
        continue;
      }

      fragments.addAll(line.fragments);
      runeIndex = line.nextIndex;
      y += lineHeight;
    }

    return (fragments: fragments, height: y);
  }

  /// 排版一行：求可用区间 → 逐区间排字。
  ({List<TextFragment> fragments, int nextIndex}) _layoutLine(
    List<int> runes,
    int start,
    double y,
    double pageWidth,
    List<ExclusionArea> exclusions,
  ) {
    // 与当前行垂直相交的排除区域，按 x 升序
    final active =
        exclusions.where((e) => e.overlapsBand(y, lineHeight)).toList()
          ..sort((a, b) => a.x.compareTo(b.x));

    final intervals = _freeIntervals(pageWidth, active);

    final fragments = <TextFragment>[];
    var index = start;

    for (final interval in intervals) {
      if (index >= runes.length) break;

      final segment = fillSegment(
        runes,
        index,
        interval.end - interval.start,
        measurer,
      );
      if (segment.text.isEmpty) continue;

      fragments.add(
        TextFragment(
          rect: GeoRect(interval.start, y, segment.width, lineHeight),
          text: segment.text,
        ),
      );
      index = segment.nextIndex;
    }

    return (fragments: fragments, nextIndex: index);
  }

  /// 求 `[0, pageWidth]` 减去若干排除区域后的可用水平区间。
  List<({double start, double end})> _freeIntervals(
    double pageWidth,
    List<ExclusionArea> exclusions,
  ) {
    final result = <({double start, double end})>[];
    var cursor = 0.0;

    for (final e in exclusions) {
      if (e.x > cursor) {
        result.add((start: cursor, end: e.x));
      }
      if (e.right > cursor) cursor = e.right;
    }
    if (cursor < pageWidth) {
      result.add((start: cursor, end: pageWidth));
    }

    return result;
  }
}
