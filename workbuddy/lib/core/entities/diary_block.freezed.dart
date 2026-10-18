// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diary_block.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
DiaryBlock _$DiaryBlockFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'text':
          return TextBlock.fromJson(
            json
          );
                case 'image':
          return ImageBlock.fromJson(
            json
          );
                case 'video':
          return VideoBlock.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'DiaryBlock',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$DiaryBlock {



  /// Serializes this DiaryBlock to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DiaryBlock);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'DiaryBlock()';
}


}

/// @nodoc
class $DiaryBlockCopyWith<$Res>  {
$DiaryBlockCopyWith(DiaryBlock _, $Res Function(DiaryBlock) __);
}


/// Adds pattern-matching-related methods to [DiaryBlock].
extension DiaryBlockPatterns on DiaryBlock {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TextBlock value)?  text,TResult Function( ImageBlock value)?  image,TResult Function( VideoBlock value)?  video,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that);case ImageBlock() when image != null:
return image(_that);case VideoBlock() when video != null:
return video(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TextBlock value)  text,required TResult Function( ImageBlock value)  image,required TResult Function( VideoBlock value)  video,}){
final _that = this;
switch (_that) {
case TextBlock():
return text(_that);case ImageBlock():
return image(_that);case VideoBlock():
return video(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TextBlock value)?  text,TResult? Function( ImageBlock value)?  image,TResult? Function( VideoBlock value)?  video,}){
final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that);case ImageBlock() when image != null:
return image(_that);case VideoBlock() when video != null:
return video(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String content)?  text,TResult Function( String path,  double scale,  double rotation)?  image,TResult Function( String path)?  video,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that.content);case ImageBlock() when image != null:
return image(_that.path,_that.scale,_that.rotation);case VideoBlock() when video != null:
return video(_that.path);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String content)  text,required TResult Function( String path,  double scale,  double rotation)  image,required TResult Function( String path)  video,}) {final _that = this;
switch (_that) {
case TextBlock():
return text(_that.content);case ImageBlock():
return image(_that.path,_that.scale,_that.rotation);case VideoBlock():
return video(_that.path);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String content)?  text,TResult? Function( String path,  double scale,  double rotation)?  image,TResult? Function( String path)?  video,}) {final _that = this;
switch (_that) {
case TextBlock() when text != null:
return text(_that.content);case ImageBlock() when image != null:
return image(_that.path,_that.scale,_that.rotation);case VideoBlock() when video != null:
return video(_that.path);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class TextBlock implements DiaryBlock {
  const TextBlock({required this.content,  String? $type}): $type = $type ?? 'text';
  factory TextBlock.fromJson(Map<String, dynamic> json) => _$TextBlockFromJson(json);

 final  String content;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of DiaryBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextBlockCopyWith<TextBlock> get copyWith => _$TextBlockCopyWithImpl<TextBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextBlockToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TextBlock&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,content);
}

@override
String toString() {
    return 'DiaryBlock.text(content: $content)';
}


}

/// @nodoc
abstract mixin class $TextBlockCopyWith<$Res> implements $DiaryBlockCopyWith<$Res> {
  factory $TextBlockCopyWith(TextBlock value, $Res Function(TextBlock) _then) = _$TextBlockCopyWithImpl;
@useResult
$Res call({
 String content
});




}
/// @nodoc
class _$TextBlockCopyWithImpl<$Res>
    implements $TextBlockCopyWith<$Res> {
  _$TextBlockCopyWithImpl(this._self, this._then);

  final TextBlock _self;
  final $Res Function(TextBlock) _then;

/// Create a copy of DiaryBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? content = null,}) {
  return _then(TextBlock(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ImageBlock implements DiaryBlock {
  const ImageBlock({required this.path, this.scale = 1.0, this.rotation = 0.0,  String? $type}): $type = $type ?? 'image';
  factory ImageBlock.fromJson(Map<String, dynamic> json) => _$ImageBlockFromJson(json);

 final  String path;
@JsonKey() final  double scale;
@JsonKey() final  double rotation;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of DiaryBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageBlockCopyWith<ImageBlock> get copyWith => _$ImageBlockCopyWithImpl<ImageBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImageBlockToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageBlock&&(identical(other.path, path) || other.path == path)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.rotation, rotation) || other.rotation == rotation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path,scale,rotation);
}

@override
String toString() {
    return 'DiaryBlock.image(path: $path, scale: $scale, rotation: $rotation)';
}


}

/// @nodoc
abstract mixin class $ImageBlockCopyWith<$Res> implements $DiaryBlockCopyWith<$Res> {
  factory $ImageBlockCopyWith(ImageBlock value, $Res Function(ImageBlock) _then) = _$ImageBlockCopyWithImpl;
@useResult
$Res call({
 String path, double scale, double rotation
});




}
/// @nodoc
class _$ImageBlockCopyWithImpl<$Res>
    implements $ImageBlockCopyWith<$Res> {
  _$ImageBlockCopyWithImpl(this._self, this._then);

  final ImageBlock _self;
  final $Res Function(ImageBlock) _then;

/// Create a copy of DiaryBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? scale = null,Object? rotation = null,}) {
  return _then(ImageBlock(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,rotation: null == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class VideoBlock implements DiaryBlock {
  const VideoBlock({required this.path,  String? $type}): $type = $type ?? 'video';
  factory VideoBlock.fromJson(Map<String, dynamic> json) => _$VideoBlockFromJson(json);

 final  String path;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of DiaryBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoBlockCopyWith<VideoBlock> get copyWith => _$VideoBlockCopyWithImpl<VideoBlock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VideoBlockToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoBlock&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path);
}

@override
String toString() {
    return 'DiaryBlock.video(path: $path)';
}


}

/// @nodoc
abstract mixin class $VideoBlockCopyWith<$Res> implements $DiaryBlockCopyWith<$Res> {
  factory $VideoBlockCopyWith(VideoBlock value, $Res Function(VideoBlock) _then) = _$VideoBlockCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$VideoBlockCopyWithImpl<$Res>
    implements $VideoBlockCopyWith<$Res> {
  _$VideoBlockCopyWithImpl(this._self, this._then);

  final VideoBlock _self;
  final $Res Function(VideoBlock) _then;

/// Create a copy of DiaryBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(VideoBlock(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
