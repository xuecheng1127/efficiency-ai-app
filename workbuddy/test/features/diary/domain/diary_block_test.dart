import 'package:flutter_test/flutter_test.dart';

import 'package:efficiency_app/features/diary/domain/diary_block.dart';

/// T22 · 正文块解析（纯 Dart，零 Flutter 依赖）
void main() {
  group('DiaryBlocks.parse · 图片标记切块', () {
    test('纯文字 → 单个文字块', () {
      final blocks = DiaryBlocks.parse('今天很好。\n明天也行。');
      expect(blocks.length, 1);
      expect((blocks.first as DiaryTextBlock).text, '今天很好。\n明天也行。');
    });

    test('文字 / 图片 / 文字 → 三块，且换行不丢', () {
      final content = '海边\n[[img:diary_media/a.jpg]]\n风很大';
      final blocks = DiaryBlocks.parse(content);
      expect(blocks.length, 3);
      expect(blocks[0], const DiaryTextBlock('海边\n'));
      expect(blocks[1], const DiaryImageBlock('diary_media/a.jpg'));
      expect(blocks[2], const DiaryTextBlock('风很大'));
    });

    test('标记独占一行才识别；行内出现按普通文字', () {
      final inline = DiaryBlocks.parse('看这张 [[img:diary_media/a.jpg]] 图');
      expect(inline.length, 1);
      expect(inline.first, isA<DiaryTextBlock>());
    });

    test('标记两侧空格容错', () {
      final blocks = DiaryBlocks.parse('  [[img:diary_media/a.jpg]]  ');
      expect(blocks.single, const DiaryImageBlock('diary_media/a.jpg'));
    });

    test('空内容 → 空列表（不崩）', () {
      expect(DiaryBlocks.parse(''), isEmpty);
    });

    test('只有图片没有文字 → 单个图片块', () {
      final blocks = DiaryBlocks.parse('[[img:diary_media/a.jpg]]');
      expect(blocks.single, const DiaryImageBlock('diary_media/a.jpg'));
    });
  });

  group('DiaryBlocks 辅助函数', () {
    test('markerFor 生成的标记能被 parse 反解（闭环）', () {
      final marker = DiaryBlocks.markerFor('diary_media/x.png');
      expect(
        DiaryBlocks.parse(marker).single,
        const DiaryImageBlock('diary_media/x.png'),
      );
    });

    test('imagePaths 按出现顺序去重', () {
      const content =
          '[[img:diary_media/a.jpg]]\n'
          '文字\n'
          '[[img:diary_media/b.jpg]]\n'
          '[[img:diary_media/a.jpg]]';
      expect(DiaryBlocks.imagePaths(content), [
        'diary_media/a.jpg',
        'diary_media/b.jpg',
      ]);
    });

    test('plainText 去掉标记（列表摘要不该出现 [[img:...]]）', () {
      const content = '第一段\n[[img:diary_media/a.jpg]]\n第二段';
      expect(DiaryBlocks.plainText(content), '第一段\n第二段');
      expect(DiaryBlocks.plainText('没有图片'), '没有图片');
    });
  });
}
