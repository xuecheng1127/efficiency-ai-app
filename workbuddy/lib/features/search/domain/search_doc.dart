/// 全局搜索的**纯数据**模型（零 Flutter、零数据库依赖）。
///
/// 为什么要先转成 [SearchDoc] 再搜：
/// 五类数据（任务模板 / 日记 / 备忘 / 采购 / 生日）的实体字段千差万别，
/// 如果搜索函数直接吃五种实体，它就会变成「五个 if + 五种字段名」的泥球，
/// 也没法脱离数据库单测。转成统一的扁平文档后，搜索就是一个
/// `List<SearchDoc> + 关键词 → List<SearchHit>` 的纯函数。
library;

/// 搜索结果的类型（顺序 = 结果分组的展示顺序）。
enum SearchCategory {
  task('任务'),
  diary('日记'),
  memo('备忘'),
  shopping('采购'),
  birthday('生日');

  const SearchCategory(this.label);

  final String label;
}

/// 一条可被搜索的扁平文档。
class SearchDoc {
  const SearchDoc({
    required this.category,
    required this.id,
    required this.title,
    this.body = '',
    this.subtitle = '',
  });

  final SearchCategory category;

  /// 原始实体的主键（点击结果时用它回查详情页）
  final int id;

  /// 主行文本。**参与搜索**（任务标题 / 日记标题 / 备忘首行 / 采购名 / 姓名）。
  final String title;

  /// 正文。**参与搜索**（日记正文 / 备忘全文 / 生日备注）；任务与采购为空。
  ///
  /// 与 [title] 分开是为了「标题命中」和「正文命中」能分优先级：
  /// 搜「跑步」时，标题叫「跑步」的任务应该排在正文里顺嘴提了一句的日记前面。
  final String body;

  /// 不参与搜索的展示信息（规则摘要 / 日期 / 分类）。
  ///
  /// 刻意不并进 [body]：否则搜「每日」会命中所有每日任务，
  /// 用户以为搜的是内容，其实是命中了元信息。
  final String subtitle;
}
