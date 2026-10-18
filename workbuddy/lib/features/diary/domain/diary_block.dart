/// 日记正文的「块」模型（纯 Dart，零 Flutter 依赖，可单测）。
///
/// V1.0 的正文仍然是**纯文本**（规格 §2：`content TEXT`，不做富文本），
/// 图片用一行标记表示：
///
/// ```
/// 今天去了海边。
/// [[img:diary_media/1712xxxx_ab12.jpg]]
/// 风很大。
/// ```
///
/// 为什么用「文本标记」而不是 JSON 块数组：
/// - 规格明确 `content` 是纯文本，且剪贴板/导出/搜索都天然可用；
/// - 图片路径仍然只在文本里出现一次，重启后靠相对路径解析，不依赖绝对路径；
/// - 解析器是纯函数，测试不需要 Flutter，也不需要文件系统。
///
/// 一个标记必须**独占一行**才被识别；出现在句子中间的 `[[img:...]]` 按普通文字处理
/// （避免用户真的想写这串字符时正文被吃掉）。
library;

/// 图片标记的正则：`[[img:<相对路径>]]`
final RegExp diaryImageMarker = RegExp(r'^\[\[img:([^\[\]]+)\]\]$');

/// 正文块
sealed class DiaryBlock {
  const DiaryBlock();
}

/// 文字块（可以包含换行，但不会包含图片标记）
final class DiaryTextBlock extends DiaryBlock {
  const DiaryTextBlock(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is DiaryTextBlock && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'DiaryTextBlock(${text.length} chars)';
}

/// 图片块（`relativePath` 形如 `diary_media/xxx.jpg`，**不是**绝对路径）
final class DiaryImageBlock extends DiaryBlock {
  const DiaryImageBlock(this.relativePath);

  final String relativePath;

  @override
  bool operator ==(Object other) =>
      other is DiaryImageBlock && other.relativePath == relativePath;

  @override
  int get hashCode => relativePath.hashCode;

  @override
  String toString() => 'DiaryImageBlock($relativePath)';
}

/// 正文解析：把纯文本切成块序列。
///
/// 规则（有意保守）：
/// 1. **空行不丢**：文字块保留原始换行，渲染时由 Text 自己换行；
/// 2. 图片标记行**前后各留一个换行**，渲染成占满整行的块，文字在其上下流动；
/// 3. 图片标记行两侧的空白会被 trim 掉再匹配（用户手滑打了空格也能识别）。
abstract final class DiaryBlocks {
  /// 生成一行图片标记（插入图片时用这个，保证与解析器一致）
  static String markerFor(String relativePath) => '[[img:$relativePath]]';

  /// 解析成块序列。空内容返回空列表。
  static List<DiaryBlock> parse(String content) {
    if (content.isEmpty) return const [];
    final blocks = <DiaryBlock>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      blocks.add(DiaryTextBlock(buffer.toString()));
      buffer.clear();
    }

    // split('\n') 会保留空行，行内 \r 由 trimRight 去掉（Windows 剪贴板）
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      final match = diaryImageMarker.firstMatch(line.trim());
      if (match != null) {
        flush();
        blocks.add(DiaryImageBlock(match.group(1)!.trim()));
      } else {
        buffer.write(line);
        if (i != lines.length - 1) buffer.write('\n');
      }
    }
    flush();
    return blocks;
  }

  /// 正文里所有图片的相对路径（按出现顺序，去重）
  static List<String> imagePaths(String content) {
    final seen = <String>{};
    final result = <String>[];
    for (final block in parse(content)) {
      if (block is DiaryImageBlock && seen.add(block.relativePath)) {
        result.add(block.relativePath);
      }
    }
    return result;
  }

  /// 去掉图片标记后剩下的纯文字（列表摘要/搜索用 —— 用户在列表里不该看到 `[[img:...]]`）
  static String plainText(String content) {
    if (!content.contains('[[img:')) return content;
    final buffer = StringBuffer();
    for (final block in parse(content)) {
      if (block is! DiaryTextBlock) continue;
      // 图片块把文字切断的地方补一个换行；文本块自己已经以换行结尾时不重复叠加
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
        buffer.write('\n');
      }
      buffer.write(block.text);
    }
    return buffer.toString().trim();
  }
}
