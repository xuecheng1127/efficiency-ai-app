/// 备忘实体（纯 Dart，零 Flutter 依赖）。
///
/// 定位（T23 规格 §1）：**极低摩擦的随手记** —— 一条备忘 = 一段纯文本 + 是否置顶 + 可选纸色。
/// 刻意不做：富文本、标签、双链、附件、云同步。
class Memo {
  const Memo({
    required this.id,
    required this.content,
    required this.pinned,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final int id;
  final String content;
  final bool pinned;

  /// `yellow` / `blue` / `green` / null（默认纸色）
  final String? color;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// 列表摘要：压平换行、截断（卡片最多显示 3 行，这里只做长度兜底）
  String summary({int maxChars = 120}) {
    final flat = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= maxChars) return flat;
    return '${flat.substring(0, maxChars)}…';
  }

  /// 首行（编辑页标题栏用；没有标题概念，取第一行当"标题"）
  String get firstLine {
    final line = content
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final t = line.trim();
    return t.length <= 24 ? t : '${t.substring(0, 24)}…';
  }

  Memo copyWith({
    String? content,
    bool? pinned,
    String? color,
    DateTime? updatedAt,
  }) {
    return Memo(
      id: id,
      content: content ?? this.content,
      pinned: pinned ?? this.pinned,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt,
    );
  }
}

/// 纸色（V1 只有这三种 + 默认；不做自定义取色器 —— 少即是多）
abstract final class MemoColor {
  static const String yellow = 'yellow';
  static const String blue = 'blue';
  static const String green = 'green';

  static const List<String?> all = [null, yellow, blue, green];

  static String label(String? color) => switch (color) {
    yellow => '黄',
    blue => '蓝',
    green => '绿',
    _ => '默认',
  };
}
