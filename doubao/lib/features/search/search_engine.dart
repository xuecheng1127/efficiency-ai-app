/// 全局搜索 · 纯函数引擎（R3）
///
/// 设计要点：
/// - 只做「候选 + 关键词 → 分组命中」的纯逻辑，不依赖 Drift / Riverpod / Widget，
///   方便单测覆盖大小写、空关键词、特殊字符等边界；
/// - 候选对象由 UI 层从各仓库行映射传入，匹配字段显式列出；
/// - 匹配为大小写不敏感的子串包含；空关键词返回空结果。

/// 五类可搜索数据
enum SearchKind { task, diary, memo, shopping, birthday }

extension SearchKindMeta on SearchKind {
  /// 分组标题（中文）
  String get label => switch (this) {
        SearchKind.task => '任务',
        SearchKind.diary => '日记',
        SearchKind.memo => '备忘录',
        SearchKind.shopping => '采购清单',
        SearchKind.birthday => '朋友生日',
      };
}

/// 搜索候选：UI 层把一行数据整理成该对象传入引擎
class SearchCandidate {
  final SearchKind kind;
  final int id;

  /// 主显示文本（标题 / 姓名 / 条目标题）
  final String title;

  /// 副显示文本（内容摘要 / 备注等）
  final String subtitle;

  /// 参与匹配的字段（标题、正文、备注等）；空串不会命中非空关键词
  final List<String> matchFields;

  const SearchCandidate({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.matchFields = const [],
  });
}

/// 单条命中结果
class SearchHit {
  final SearchKind kind;
  final int id;
  final String title;
  final String subtitle;

  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle = '',
  });
}

/// 分组后的搜索结果
class SearchResult {
  /// 按类型分组，每组保留全部命中（截断 / 查看全部由 UI 层处理）
  final Map<SearchKind, List<SearchHit>> groups;

  const SearchResult(this.groups);

  factory SearchResult.empty() => const SearchResult(<SearchKind, List<SearchHit>>{});

  bool get isEmpty => groups.values.every((list) => list.isEmpty);

  int get totalCount =>
      groups.values.fold<int>(0, (sum, list) => sum + list.length);

  /// 指定分组的命中数
  int countOf(SearchKind kind) => groups[kind]?.length ?? 0;
}

/// 大小写不敏感子串匹配；关键词去空白后为空则返回空结果。
SearchResult runSearch(Iterable<SearchCandidate> candidates, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return SearchResult.empty();

  final groups = <SearchKind, List<SearchHit>>{};
  for (final c in candidates) {
    final matched = c.matchFields.any(
      (field) => field.toLowerCase().contains(q),
    );
    if (!matched) continue;
    groups
        .putIfAbsent(c.kind, () => <SearchHit>[])
        .add(SearchHit(
          kind: c.kind,
          id: c.id,
          title: c.title,
          subtitle: c.subtitle,
        ));
  }
  return SearchResult(groups);
}
