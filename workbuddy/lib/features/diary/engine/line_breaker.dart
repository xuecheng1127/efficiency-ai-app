import 'text_measure.dart';

/// 中文排版禁则字符集（标点避头尾）。
abstract final class CjkRules {
  /// 行首禁则（避头）：这些标点不能出现在行首。
  static const Set<String> lineStartForbidden = {
    '，',
    '。',
    '、',
    '；',
    '：',
    '！',
    '？',
    '）',
    '》',
    '】',
    '」',
    '』',
    '〉',
    '〕',
    '…',
    '—',
    '～',
    '·',
  };

  /// 行尾禁则（避尾）：这些标点不能出现在行尾。
  static const Set<String> lineEndForbidden = {
    '（',
    '《',
    '【',
    '「',
    '『',
    '〈',
    '〔',
  };
}

/// 贪心排字 + 标点避头尾（核心算法，被 [LineBreaker] 与绕排引擎复用）。
///
/// 在给定宽度内尽量多地排入字符，并做禁则处理：
/// - **避头**：断点后若下一字符是行首禁则，按降级顺序处理——
///   悬挂标点（把标点挤到行尾，允许轻微超宽）→ 字距挤压（5% 内）→ 强制带走上一字；
///   PoC 实现「悬挂标点」作为主策略，其余降级留作生产扩展点。
/// - **避尾**：本段行尾若是行尾禁则，回退该字符交给下一行。
///
/// 返回排出的文本、累计宽度、下一个待处理字符索引。
({String text, double width, int nextIndex}) fillSegment(
  List<int> runes,
  int start,
  double maxWidth,
  TextMeasurer measurer,
) {
  final buffer = StringBuffer();
  var width = 0.0;
  var index = start;

  // 贪心填字：放不下即停
  while (index < runes.length) {
    final ch = String.fromCharCode(runes[index]);
    final w = measurer.charWidth(ch);
    if (buffer.isNotEmpty && width + w > maxWidth) break;
    buffer.write(ch);
    width += w;
    index++;
  }

  // 单字符超宽兜底：至少排入一个字符
  if (buffer.isEmpty && index < runes.length) {
    final ch = String.fromCharCode(runes[index]);
    buffer.write(ch);
    width = measurer.charWidth(ch);
    index++;
  }

  var text = buffer.toString();

  // —— 避头：下一字符为行首禁则，悬挂标点到本段行尾 ——
  if (index < runes.length) {
    final next = String.fromCharCode(runes[index]);
    if (CjkRules.lineStartForbidden.contains(next)) {
      text += next;
      width += measurer.charWidth(next);
      index++;
    }
  }

  // —— 避尾：本段行尾为行尾禁则，回退该字符 ——
  while (text.isNotEmpty) {
    final lastChar = String.fromCharCode(text.runes.last);
    if (!CjkRules.lineEndForbidden.contains(lastChar)) break;
    text = text.substring(0, text.length - lastChar.length);
    width -= measurer.charWidth(lastChar);
    index--;
  }

  return (text: text, width: width, nextIndex: index);
}

/// 断行器：把一段文本断为多行，附带中文标点避头尾。
class LineBreaker {
  LineBreaker({required this.measurer, required this.maxWidth});

  final TextMeasurer measurer;
  final double maxWidth;

  /// 将文本断为多行。
  List<String> breakLines(String text) {
    final result = <String>[];
    final runes = text.runes.toList();
    var index = 0;

    while (index < runes.length) {
      final segment = fillSegment(runes, index, maxWidth, measurer);
      result.add(segment.text);
      index = segment.nextIndex;
    }
    return result;
  }
}
