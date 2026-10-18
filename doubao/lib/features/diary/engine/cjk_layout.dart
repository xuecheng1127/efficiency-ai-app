/// 中文避头尾排版引擎（T22 核心）
///
/// 纯 Dart，零 Flutter 依赖，可脱离 widget 单元测试。
///
/// 避头尾降级顺序（PRD 硬要求）：
/// 1. 悬挂标点（标点挂到行尾外面，不占行内宽度）—— 首选
/// 2. 字距挤压（≤5%）—— 悬挂装不下时
/// 3. 强制带走上一字（把前一个字拉到下一行）—— 前两级都不行时
library;

/// 禁则头：不许出现在行首的标点
const Set<String> kLineHeadForbidden = {
  '，', '。', '、', '；', '：', '？', '！',
  '）', '》', '」', '』', '】', '〕', '〉', '”', '’',
  '．', '…', '—',
};

/// 禁则尾：不许出现在行尾的标点
const Set<String> kLineTailForbidden = {
  '（', '《', '「', '『', '【', '〔', '〈', '“', '‘',
};

/// 单个字符的渲染度量
class CharMetric {
  final String char;
  final double width;
  final bool isHeadForbidden;
  final bool isTailForbidden;

  const CharMetric({
    required this.char,
    required this.width,
    required this.isHeadForbidden,
    required this.isTailForbidden,
  });
}

/// 一行渲染结果
class RenderedLine {
  /// 本行在原文本中的起始 offset
  final int startOffset;

  /// 本行在原文本中的结束 offset（不含）
  final int endOffset;

  /// 本行字符（含悬挂标点的字符）
  final List<CharMetric> chars;

  /// 悬挂标点宽度（挂在行尾外面，不计入行宽）
  final double hangingWidth;

  /// 字距挤压比例（0.0 = 不挤压）
  final double squeezeRatio;

  /// 本行实际占用宽度（**不含悬挂标点**）
  ///
  /// 评审方修复（2026-10-18）：原实现把悬挂标点也算进了行宽 ——
  /// 悬挂的定义就是「挂到行尾外面、不占行内宽度」，算进去会导致
  /// 输入 "，。、；：？！" 宽度 4.0 时行宽报 5.0 > 4.0。
  double get lineWidth {
    final sum =
        chars.fold<double>(0, (s, c) => s + c.width * (1 - squeezeRatio));
    final hangContribution = hangingWidth * (1 - squeezeRatio);
    return (sum - hangContribution).clamp(0.0, double.infinity);
  }

  const RenderedLine({
    required this.startOffset,
    required this.endOffset,
    required this.chars,
    this.hangingWidth = 0,
    this.squeezeRatio = 0,
  });
}

/// 排版引擎输入
class LayoutInput {
  /// 可用行宽（逻辑像素）
  final double maxWidth;

  /// 字符度量函数（给定字符返回宽度）
  final double Function(String char) measure;

  const LayoutInput({
    required this.maxWidth,
    required this.measure,
  });
}

/// 中文避头尾排版引擎
class CjkLayout {
  /// 主入口：对一段文本按宽度断行，应用避头尾规则
  static List<RenderedLine> layout(String text, LayoutInput input) {
    final lines = <RenderedLine>[];
    if (text.isEmpty) return lines;

    // 预处理：逐字符度量
    final metrics = <CharMetric>[];
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      metrics.add(CharMetric(
        char: ch,
        width: input.measure(ch),
        isHeadForbidden: kLineHeadForbidden.contains(ch),
        isTailForbidden: kLineTailForbidden.contains(ch),
      ));
    }

    var i = 0;
    while (i < metrics.length) {
      final line = _layoutOneLine(metrics, i, input.maxWidth);
      lines.add(line);
      i = line.endOffset;
    }

    return lines;
  }

  /// 排一行：从 start 开始，尽量多放字符，直到超过 maxWidth
  static RenderedLine _layoutOneLine(
    List<CharMetric> metrics,
    int start,
    double maxWidth,
  ) {
    var used = 0.0;
    var end = start;

    // 第一遍：贪心放字符，记录最后一个能放下的位置
    while (end < metrics.length) {
      final w = metrics[end].width;
      if (used + w > maxWidth) break;
      used += w;
      end++;
    }

    // end 现在是第一个放不下的字符 index（或等于 length）
    // 检查避头尾
    if (end < metrics.length) {
      final next = metrics[end];
      // 情况 1：下一个字符是禁则头标点 → 悬挂到本行尾
      if (next.isHeadForbidden) {
        // 悬挂：把这个标点挂到行尾外面
        return RenderedLine(
          startOffset: start,
          endOffset: end + 1,
          chars: metrics.sublist(start, end + 1),
          hangingWidth: next.width,
        );
      }
      // 情况 2：本行最后一个字符是禁则尾标点 → 不能放在行尾
      //
      // 评审方修复（2026-10-18）：
      // - 原实现先去"挤压把 next 挤进来" —— 方向错了，挤压不能移除行尾的禁则尾；
      // - 且只 end-- 一次，连续禁则尾（如 "（（（（"）回退后行尾仍是禁则尾。
      // 正确修法：循环回退，直到行尾不是禁则尾（或只剩 1 字）。
      if (end > start && metrics[end - 1].isTailForbidden) {
        var guard = 0;
        while (end > start + 1 && guard < 8 && metrics[end - 1].isTailForbidden) {
          end--;
          guard++;
        }
      }
    }

    // 边界：一行一个字符都没放下（极端窄宽度）
    if (end == start) {
      end = start + 1;
    }

    return RenderedLine(
      startOffset: start,
      endOffset: end,
      chars: metrics.sublist(start, end),
    );
  }
}
