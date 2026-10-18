import 'package:flutter/material.dart';

/// 搜索命中的高亮文本（不区分大小写，支持多处命中）。
///
/// 用 `Text.rich` 而不是把整段换成 HTML/Markdown —— V1.0 只要"看得见命中"，
/// 不引入任何富文本依赖。
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.keyword,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final String keyword;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium;
    final k = keyword.trim();
    if (k.isEmpty || !text.toLowerCase().contains(k.toLowerCase())) {
      return Text(text, style: base, maxLines: maxLines, overflow: overflow);
    }

    final lower = text.toLowerCase();
    final lk = k.toLowerCase();
    final spans = <TextSpan>[];
    var cursor = 0;
    while (true) {
      final hit = lower.indexOf(lk, cursor);
      if (hit < 0) {
        if (cursor < text.length) {
          spans.add(TextSpan(text: text.substring(cursor)));
        }
        break;
      }
      if (hit > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, hit)));
      }
      spans.add(
        TextSpan(
          text: text.substring(hit, hit + k.length),
          style: TextStyle(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.24),
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
      cursor = hit + k.length;
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
