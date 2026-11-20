import 'package:efficiency_app/features/search/domain/search_doc.dart';
import 'package:efficiency_app/features/search/domain/search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 全局搜索的纯函数测试（R1 任务 2 验收项）。
///
/// 这里**不碰数据库、不建 Widget**：搜索的坑几乎全在「命中/优先级/截断」，
/// 用纯数据测最快也最准。
void main() {
  SearchDoc doc(
    SearchCategory category,
    int id,
    String title, {
    String body = '',
  }) {
    return SearchDoc(category: category, id: id, title: title, body: body);
  }

  group('searchDocs · 命中规则', () {
    test('空关键词 / 全空白 → 不返回任何结果', () {
      final docs = [doc(SearchCategory.task, 1, '跑步')];

      expect(searchDocs(docs, ''), isEmpty);
      expect(searchDocs(docs, '   '), isEmpty);
      expect(searchDocs(docs, '\n\t'), isEmpty);
    });

    test('标题命中（中文，无需分词）', () {
      final docs = [
        doc(SearchCategory.task, 1, '晨间跑步'),
        doc(SearchCategory.task, 2, '读书'),
      ];

      final hits = searchDocs(docs, '跑步');

      expect(hits, hasLength(1));
      expect(hits.single.doc.id, 1);
      expect(hits.single.titleHit, isTrue);
    });

    test('正文命中：标题不匹配、正文匹配也算命中', () {
      final docs = [
        doc(SearchCategory.diary, 7, '10月20日', body: '今天去河边跑了五公里'),
      ];

      final hits = searchDocs(docs, '五公里');

      expect(hits, hasLength(1));
      expect(hits.single.titleHit, isFalse);
      expect(hits.single.snippet, contains('五公里'));
    });

    test('大小写不敏感（英文关键词）', () {
      final docs = [
        doc(SearchCategory.memo, 3, 'Flutter 构建'),
        doc(SearchCategory.memo, 4, '其他'),
      ];

      expect(searchDocs(docs, 'flutter'), hasLength(1));
      expect(searchDocs(docs, 'FLUTTER'), hasLength(1));
      expect(searchDocs(docs, 'flut'), hasLength(1));
    });

    test('标题命中排在正文命中之前，同权重保持传入顺序', () {
      final docs = [
        doc(SearchCategory.diary, 1, '随笔', body: '今天谈到了跑步'),
        doc(SearchCategory.task, 2, '跑步 30 分钟'),
        doc(SearchCategory.diary, 3, '周记', body: '跑步让我开心'),
        doc(SearchCategory.task, 4, '跑步拉伸'),
      ];

      final hits = searchDocs(docs, '跑步');

      expect(hits.map((h) => h.doc.id).toList(), [2, 4, 1, 3]);
      expect(hits.take(2).every((h) => h.titleHit), isTrue);
      expect(hits.skip(2).every((h) => !h.titleHit), isTrue);
    });

    test('跨类型：同一个词可以同时命中 5 类', () {
      final docs = [
        doc(SearchCategory.task, 1, '买牛奶'),
        doc(SearchCategory.diary, 2, '今天', body: '路过超市买牛奶'),
        doc(SearchCategory.memo, 3, '买牛奶', body: '买牛奶'),
        doc(SearchCategory.shopping, 4, '牛奶'),
        doc(SearchCategory.birthday, 5, '小王', body: '爱喝牛奶'),
      ];

      final hits = searchDocs(docs, '牛奶');
      final groups = groupSearchHits(hits);

      expect(hits, hasLength(5));
      expect(groups.map((g) => g.category).toList(), SearchCategory.values);
      expect(groups.every((g) => g.total == 1), isTrue);
    });
  });

  group('snippetAround · 片段截取', () {
    test('短文本原样返回（不补省略号）', () {
      expect(snippetAround('买牛奶', '牛奶'), '买牛奶');
    });

    test('长文本命中在中间：前后都有省略号且包含关键词', () {
      final long = '${'前' * 80}关键词${'后' * 80}';

      final snippet = snippetAround(long, '关键词', maxChars: 40);

      expect(snippet, contains('关键词'));
      expect(snippet.startsWith('…'), isTrue);
      expect(snippet.endsWith('…'), isTrue);
      // 截断后长度 = maxChars + 两个省略号
      expect(snippet.length, lessThanOrEqualTo(42));
    });

    test('长文本命中在开头：只在尾部补省略号', () {
      final long = '关键词${'后' * 80}';

      final snippet = snippetAround(long, '关键词', maxChars: 20);

      expect(snippet.startsWith('关键词'), isTrue);
      expect(snippet.endsWith('…'), isTrue);
    });

    test('换行与连续空白被压成单空格', () {
      const text = '第一行\n\n第二行   有宽空格';

      final snippet = snippetAround(text, '第二行');

      expect(snippet, '第一行 第二行 有宽空格');
    });

    test('空正文 → 空片段（不产生空字符串卡片）', () {
      expect(snippetAround('', '牛奶'), '');
      expect(snippetAround('   \n ', '牛奶'), '');
    });
  });

  group('groupSearchHits · 分组与截断', () {
    List<SearchHit> manyHits(SearchCategory category, int count) {
      return [
        for (var i = 0; i < count; i++)
          SearchHit(
            doc: doc(category, i, '条 $i'),
            titleHit: true,
            snippet: '',
          ),
      ];
    }

    test('每组默认最多 5 条，total 记录真实命中数', () {
      final groups = groupSearchHits(manyHits(SearchCategory.memo, 7));

      expect(groups, hasLength(1));
      expect(groups.single.hits, hasLength(5));
      expect(groups.single.total, 7);
      expect(groups.single.hasMore, isTrue);
    });

    test('expanded 里的类型不截断', () {
      final groups = groupSearchHits(
        manyHits(SearchCategory.memo, 7),
        expanded: {SearchCategory.memo},
      );

      expect(groups.single.hits, hasLength(7));
      expect(groups.single.hasMore, isFalse);
    });

    test('恰好 5 条时 hasMore 为 false（不该出现「查看全部 5」）', () {
      final groups = groupSearchHits(manyHits(SearchCategory.shopping, 5));

      expect(groups.single.hits, hasLength(5));
      expect(groups.single.hasMore, isFalse);
    });

    test('组顺序固定为 enum 顺序，与命中数量无关', () {
      final hits = [
        ...manyHits(SearchCategory.birthday, 3),
        ...manyHits(SearchCategory.task, 1),
        ...manyHits(SearchCategory.memo, 2),
      ];

      final groups = groupSearchHits(hits);

      expect(groups.map((g) => g.category).toList(), [
        SearchCategory.task,
        SearchCategory.memo,
        SearchCategory.birthday,
      ]);
    });

    test('没有命中的类型不产生空组', () {
      final groups = groupSearchHits(manyHits(SearchCategory.diary, 1));

      expect(groups, hasLength(1));
      expect(groups.single.category, SearchCategory.diary);
    });
  });
}
