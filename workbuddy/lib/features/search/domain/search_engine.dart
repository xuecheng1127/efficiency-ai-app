/// 全局搜索的匹配 / 分组逻辑 —— **纯函数**，无 IO、无 Flutter。
///
/// 之所以全部抽成顶层函数：搜索最容易出错的地方不是 UI，而是
/// 「大小写、空白、命中位置、分组截断」这些细节，只有纯函数才测得干净
/// （见 `test/features/search/search_engine_test.dart`）。
library;

import 'dart:math' as math;

import 'search_doc.dart';

/// 一条命中。
class SearchHit {
  const SearchHit({
    required this.doc,
    required this.titleHit,
    required this.snippet,
  });

  final SearchDoc doc;

  /// 命中位置是否在标题上（决定排序优先级与展示态）
  final bool titleHit;

  /// 展示用的正文片段；正文为空或未命中时为空串。
  ///
  /// 只截命中附近的一段，而不是把整篇正文塞进列表 —— 一屏看到「为什么命中」
  /// 比看到整段内容更有用，也避免长日记把结果页撑成阅读器。
  final String snippet;
}

/// 一组（同一类型）的结果。
class SearchGroup {
  const SearchGroup({
    required this.category,
    required this.hits,
    required this.total,
  });

  final SearchCategory category;

  /// 本组实际要展示的条目（可能是截断后的前 N 条）
  final List<SearchHit> hits;

  /// 本组命中总数（用于「查看全部（N）」）
  final int total;

  bool get hasMore => total > hits.length;
}

/// 全量搜索：标题 / 正文任一命中即算命中。
///
/// 排序规则（稳定）：
/// 1. 标题命中的排在正文命中之前；
/// 2. 同一优先级内**保持传入顺序** —— 各数据源已经按自己的业务排好
///    （备忘置顶在前、日记按日期倒序、任务按创建顺序），搜索不该打乱它。
///
/// 关键词为空（或全是空白）→ 返回空列表：搜索页此时展示「搜什么」的引导态，
/// 而不是把整个数据库当结果倒出来。
List<SearchHit> searchDocs(Iterable<SearchDoc> docs, String keyword) {
  final k = normalizeKeyword(keyword);
  if (k.isEmpty) return const [];

  final order = <SearchHit>[];
  final titleHits = <SearchHit>[];
  final bodyHits = <SearchHit>[];

  for (final doc in docs) {
    final inTitle = doc.title.toLowerCase().contains(k);
    final inBody = doc.body.toLowerCase().contains(k);
    if (!inTitle && !inBody) continue;

    final hit = SearchHit(
      doc: doc,
      titleHit: inTitle,
      snippet: inBody ? snippetAround(doc.body, k) : '',
    );
    (inTitle ? titleHits : bodyHits).add(hit);
  }

  // 两段拼接而不是 sort(comparator)：Dart 的 List.sort 不保证稳定，
  // 用「返回 0」的 comparator 会悄悄打乱同权重结果。
  order.addAll(titleHits);
  order.addAll(bodyHits);
  return order;
}

/// 关键词归一化：去首尾空白 + 转小写（中文不受影响，英文大小写不敏感）。
String normalizeKeyword(String keyword) => keyword.trim().toLowerCase();

/// 截取命中位置附近的一段文本。
///
/// - 全文不超过 [maxChars] → 原样返回（不做无意义的省略）；
/// - 命中在很后面 → 前面补省略号，让用户一眼看到命中的词；
/// - 命中在开头 → 只截尾部。
///
/// 先把换行/连续空白压成单空格：日记正文里的换行在单行摘要里会变成
/// 一个大空洞，看起来像两段无关的话被硬拼在一起。
String snippetAround(String text, String keyword, {int maxChars = 60}) {
  final k = normalizeKeyword(keyword);
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return '';
  if (k.isEmpty || flat.length <= maxChars) return flat;

  final hit = flat.toLowerCase().indexOf(k);
  if (hit < 0) return '${_safeCut(flat, maxChars)}…';

  // 命中词前面留 1/3 的上下文，后面自然吃完剩下的空间
  var start = hit - maxChars ~/ 3;
  if (start < 0) start = 0;
  var end = start + maxChars;
  if (end > flat.length) {
    end = flat.length;
    start = math.max(0, end - maxChars);
  }
  final head = start > 0 ? '…' : '';
  final tail = end < flat.length ? '…' : '';
  return '$head${flat.substring(start, end)}$tail';
}

/// 按 UTF-16 截断时避开「半个 emoji」：切点落在代理对中间就退一格。
String _safeCut(String s, int end) {
  if (end <= 0 || end >= s.length) return s;
  final isLowSurrogate =
      s.codeUnitAt(end) >= 0xDC00 && s.codeUnitAt(end) <= 0xDFFF;
  return s.substring(0, isLowSurrogate ? end - 1 : end);
}

/// 按类型分组。
///
/// [limit] 是每组默认展示条数（需求：每组最多 5 条 + 「查看全部」）；
/// [expanded] 里的类型不截断（用户点了「查看全部」）。
/// 组顺序固定按 [SearchCategory.values]，不按命中数排序 —— 位置稳定，
/// 用户第二次搜索时不用重新找「日记那组跑哪去了」。
List<SearchGroup> groupSearchHits(
  List<SearchHit> hits, {
  int limit = 5,
  Set<SearchCategory> expanded = const {},
}) {
  final groups = <SearchGroup>[];
  for (final category in SearchCategory.values) {
    final all = hits.where((h) => h.doc.category == category).toList();
    if (all.isEmpty) continue;
    final visible = expanded.contains(category)
        ? all
        : all.take(math.min(limit, all.length)).toList();
    groups.add(
      SearchGroup(category: category, hits: visible, total: all.length),
    );
  }
  return groups;
}
