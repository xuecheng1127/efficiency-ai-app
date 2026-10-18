/// 全局尺寸常量（见需求文档「全局视觉规范 · 布局规则」）
abstract final class AppDimens {
  /// 全局水平内边距
  static const double pagePadding = 16;

  /// 卡片圆角
  static const double cardRadius = 12;

  /// 可点击区域最小尺寸
  static const double minTapSize = 44;

  /// 区块（section）之间的间距
  static const double sectionGap = 20;

  /// 区块标题与其卡片之间的间距
  static const double sectionHeaderGap = 8;

  /// 卡片之间的间距
  static const double cardGap = 12;

  /// 卡片内部上下内边距
  static const double cardPadding = 4;

  /// 图标列宽（用于 Divider 缩进与卡片内容对齐）
  static const double leadingIconWidth = 40;

  /// chip / 标签类元素之间的间距（比区块间距小，避免换行后右侧留下大片空白）
  static const double chipGap = 6;

  /// 日记图片四周安全边距（避免文字贴边）
  static const double mediaSafeMargin = 8;

  /// 日记行高 = 字号 × 1.5
  static const double lineHeightRatio = 1.5;
}
