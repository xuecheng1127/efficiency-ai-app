import 'diary_block.dart';

/// 日记实体（纯 Dart，UI 与数据层共用）。
///
/// 刻意**不**直接用 Drift 生成的行类：Domain 一旦绑死 ORM，换库/换字段就得全改
/// （T01 红线第 4 条：禁止让 Domain 实体直接使用 Drift 生成的 row 类）。
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.templateType,
    required this.fontSize,
    required this.fontFamily,
    required this.coverPath,
    required this.diaryDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final int id;
  final String title;
  final String content;

  /// `lined` = 横线本 / `blank` = 空白本
  final String templateType;

  final double fontSize;
  final String? fontFamily;

  /// 图片/封面**相对路径**（如 `diary_media/xxx.jpg`）
  final String? coverPath;

  /// 归属日（当天 0 点）
  final DateTime diaryDate;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isLined => templateType == DiaryTemplateType.lined;
  bool get isEmptyBody => content.trim().isEmpty && title.trim().isEmpty;

  /// 列表用摘要：去掉图片标记、把换行压成空格并截断
  String summary({int maxChars = 80}) {
    final flat = DiaryBlocks.plainText(
      content,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty && DiaryBlocks.imagePaths(content).isNotEmpty) {
      return '[图片]';
    }
    if (flat.length <= maxChars) return flat;
    return '${flat.substring(0, maxChars)}…';
  }

  DiaryEntry copyWith({
    String? title,
    String? content,
    String? templateType,
    double? fontSize,
    String? fontFamily,
    String? coverPath,
    DateTime? diaryDate,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return DiaryEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      templateType: templateType ?? this.templateType,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      coverPath: coverPath ?? this.coverPath,
      diaryDate: diaryDate ?? this.diaryDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

/// 模板类型（用字符串而不是 enum，直接落库，避免映射表）
abstract final class DiaryTemplateType {
  static const String lined = 'lined';
  static const String blank = 'blank';

  static String label(String type) => type == blank ? '空白本' : '横线本';

  static String toggle(String type) => type == blank ? lined : blank;
}

/// 日期分组用的桶
enum DiaryDateBucket { today, yesterday, earlier }

/// 一条日记在列表里的呈现单元（含高亮片段）
class DiaryListRow {
  const DiaryListRow({required this.entry, required this.bucket});

  final DiaryEntry entry;
  final DiaryDateBucket bucket;

  static String bucketLabel(DiaryDateBucket b) => switch (b) {
    DiaryDateBucket.today => '今天',
    DiaryDateBucket.yesterday => '昨天',
    DiaryDateBucket.earlier => '更早',
  };
}
