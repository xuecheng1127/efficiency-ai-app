import 'package:freezed_annotation/freezed_annotation.dart';

part 'diary_block.freezed.dart';
part 'diary_block.g.dart';

/// 日记排版区块：文字与媒体统一抽象为区块，按序渲染。
///
/// V1.0 采用「区块级流式排布」（图片作为独立块级元素，文字在上下流式排布）；
/// 「图片任意位置自由拖拽 + 文字实时避让」降级至 V1.1（见 ADR-005）。
/// 媒体仅存相对路径，图片/视频文件位于应用专属目录，严禁 Base64 入库。
@freezed
sealed class DiaryBlock with _$DiaryBlock {
  const factory DiaryBlock.text({required String content}) = TextBlock;

  const factory DiaryBlock.image({
    required String path,
    @Default(1.0) double scale,
    @Default(0.0) double rotation,
  }) = ImageBlock;

  const factory DiaryBlock.video({required String path}) = VideoBlock;

  factory DiaryBlock.fromJson(Map<String, dynamic> json) =>
      _$DiaryBlockFromJson(json);
}
