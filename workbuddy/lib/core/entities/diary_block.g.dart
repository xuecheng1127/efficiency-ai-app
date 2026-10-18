// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_block.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TextBlock _$TextBlockFromJson(Map<String, dynamic> json) => TextBlock(
  content: json['content'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$TextBlockToJson(TextBlock instance) => <String, dynamic>{
  'content': instance.content,
  'runtimeType': instance.$type,
};

ImageBlock _$ImageBlockFromJson(Map<String, dynamic> json) => ImageBlock(
  path: json['path'] as String,
  scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
  rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$ImageBlockToJson(ImageBlock instance) =>
    <String, dynamic>{
      'path': instance.path,
      'scale': instance.scale,
      'rotation': instance.rotation,
      'runtimeType': instance.$type,
    };

VideoBlock _$VideoBlockFromJson(Map<String, dynamic> json) => VideoBlock(
  path: json['path'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$VideoBlockToJson(VideoBlock instance) =>
    <String, dynamic>{'path': instance.path, 'runtimeType': instance.$type};
