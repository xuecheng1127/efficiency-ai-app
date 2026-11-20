import 'package:efficiency_app/features/search/search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// R3：全局搜索纯函数引擎验证
void main() {
  List<SearchCandidate> buildCandidates() => [
        SearchCandidate(
            kind: SearchKind.task,
            id: 1,
            title: '背英语单词',
            matchFields: ['背英语单词']),
        SearchCandidate(
            kind: SearchKind.task,
            id: 2,
            title: '跑步五公里',
            matchFields: ['跑步五公里']),
        SearchCandidate(
            kind: SearchKind.diary,
            id: 11,
            title: '周末日记',
            subtitle: '今天背了很多英语单词，很充实',
            matchFields: ['周末日记', '今天背了很多英语单词，很充实']),
        SearchCandidate(
            kind: SearchKind.diary,
            id: 12,
            title: '运动记录',
            subtitle: '下午跑步五公里',
            matchFields: ['运动记录', '下午跑步五公里']),
        SearchCandidate(
            kind: SearchKind.memo,
            id: 21,
            title: '备忘录',
            subtitle: '记得买英语单词本',
            matchFields: ['记得买英语单词本']),
        SearchCandidate(
            kind: SearchKind.shopping,
            id: 31,
            title: '牛奶',
            matchFields: ['牛奶']),
        SearchCandidate(
            kind: SearchKind.birthday,
            id: 41,
            title: '小李',
            subtitle: '备注：送英语参考书',
            matchFields: ['小李', '送英语参考书']),
      ];

  test('跨类型命中：同一关键词在任务/日记/备忘录/生日四类中同时命中', () {
    final result = runSearch(buildCandidates(), '英语');

    expect(result.totalCount, 4);
    expect(result.countOf(SearchKind.task), 1);
    expect(result.countOf(SearchKind.diary), 1);
    expect(result.countOf(SearchKind.memo), 1);
    expect(result.countOf(SearchKind.birthday), 1);
    expect(result.countOf(SearchKind.shopping), 0);

    final diaryHit = result.groups[SearchKind.diary]!.single;
    expect(diaryHit.id, 11);
    expect(diaryHit.title, '周末日记');
  });

  test('大小写不敏感：英文关键词大小写均可命中', () {
    final candidates = [
      SearchCandidate(
          kind: SearchKind.memo,
          id: 1,
          title: 'TODO',
          matchFields: ['TODO meeting']),
    ];
    expect(runSearch(candidates, 'todo').totalCount, 1);
    expect(runSearch(candidates, 'TODO').totalCount, 1);
    expect(runSearch(candidates, 'Meeting').totalCount, 1);
  });

  test('空关键词与纯空白返回空结果', () {
    expect(runSearch(buildCandidates(), '').isEmpty, isTrue);
    expect(runSearch(buildCandidates(), '   ').isEmpty, isTrue);
    expect(runSearch(buildCandidates(), '\t\n ').isEmpty, isTrue);
  });

  test('子串部分匹配命中，整词不要求相等', () {
    final result = runSearch(buildCandidates(), '单词');
    expect(result.countOf(SearchKind.task), 1);
    expect(result.countOf(SearchKind.memo), 1);
  });

  test('特殊字符与表情作为关键词不抛异常，未命中即空', () {
    expect(() => runSearch(buildCandidates(), '('), returnsNormally);
    expect(() => runSearch(buildCandidates(), '? * [ ] 🎉'), returnsNormally);
    final result = runSearch(buildCandidates(), '? * [ ] 🎉');
    expect(result.isEmpty, isTrue);
  });

  test('无任何命中时分组为空', () {
    final result = runSearch(buildCandidates(), '不存在的词 xyzzy');
    expect(result.isEmpty, isTrue);
    expect(result.totalCount, 0);
  });
}
