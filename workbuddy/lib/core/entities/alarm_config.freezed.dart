// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'alarm_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AlarmConfig {

/// 是否启用
 bool get enabled;/// 提醒时间 HH:mm
 String get time;/// 提前 15 分钟提醒
 bool get advance15;/// 提前 30 分钟提醒
 bool get advance30;/// 贪睡最大次数（最多 3 次）
 int get maxSnooze;/// 铃音 id（内置 3-5 首轻柔纯音乐 / 本地音频路径）
 String get sound;
/// Create a copy of AlarmConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlarmConfigCopyWith<AlarmConfig> get copyWith => _$AlarmConfigCopyWithImpl<AlarmConfig>(this as AlarmConfig, _$identity);

  /// Serializes this AlarmConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AlarmConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlarmConfig&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.time, _this.time) || other.time == _this.time)&&(identical(other.advance15, _this.advance15) || other.advance15 == _this.advance15)&&(identical(other.advance30, _this.advance30) || other.advance30 == _this.advance30)&&(identical(other.maxSnooze, _this.maxSnooze) || other.maxSnooze == _this.maxSnooze)&&(identical(other.sound, _this.sound) || other.sound == _this.sound));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AlarmConfig;
  return Object.hash(runtimeType,_this.enabled,_this.time,_this.advance15,_this.advance30,_this.maxSnooze,_this.sound);
}

@override
String toString() {
  final _this = this as AlarmConfig;
  return 'AlarmConfig(enabled: ${_this.enabled}, time: ${_this.time}, advance15: ${_this.advance15}, advance30: ${_this.advance30}, maxSnooze: ${_this.maxSnooze}, sound: ${_this.sound})';
}


}

/// @nodoc
abstract mixin class $AlarmConfigCopyWith<$Res>  {
  factory $AlarmConfigCopyWith(AlarmConfig value, $Res Function(AlarmConfig) _then) = _$AlarmConfigCopyWithImpl;
@useResult
$Res call({
 bool enabled, String time, bool advance15, bool advance30, int maxSnooze, String sound
});




}
/// @nodoc
class _$AlarmConfigCopyWithImpl<$Res>
    implements $AlarmConfigCopyWith<$Res> {
  _$AlarmConfigCopyWithImpl(this._self, this._then);

  final AlarmConfig _self;
  final $Res Function(AlarmConfig) _then;

/// Create a copy of AlarmConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? time = null,Object? advance15 = null,Object? advance30 = null,Object? maxSnooze = null,Object? sound = null,}) {
  return _then(AlarmConfig(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,advance15: null == advance15 ? _self.advance15 : advance15 // ignore: cast_nullable_to_non_nullable
as bool,advance30: null == advance30 ? _self.advance30 : advance30 // ignore: cast_nullable_to_non_nullable
as bool,maxSnooze: null == maxSnooze ? _self.maxSnooze : maxSnooze // ignore: cast_nullable_to_non_nullable
as int,sound: null == sound ? _self.sound : sound // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AlarmConfig].
extension AlarmConfigPatterns on AlarmConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlarmConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlarmConfig() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlarmConfig value)  $default,){
final _that = this;
switch (_that) {
case _AlarmConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlarmConfig value)?  $default,){
final _that = this;
switch (_that) {
case _AlarmConfig() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  String time,  bool advance15,  bool advance30,  int maxSnooze,  String sound)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlarmConfig() when $default != null:
return $default(_that.enabled,_that.time,_that.advance15,_that.advance30,_that.maxSnooze,_that.sound);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  String time,  bool advance15,  bool advance30,  int maxSnooze,  String sound)  $default,) {final _that = this;
switch (_that) {
case _AlarmConfig():
return $default(_that.enabled,_that.time,_that.advance15,_that.advance30,_that.maxSnooze,_that.sound);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  String time,  bool advance15,  bool advance30,  int maxSnooze,  String sound)?  $default,) {final _that = this;
switch (_that) {
case _AlarmConfig() when $default != null:
return $default(_that.enabled,_that.time,_that.advance15,_that.advance30,_that.maxSnooze,_that.sound);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AlarmConfig implements AlarmConfig {
  const _AlarmConfig({this.enabled = true, this.time = '09:00', this.advance15 = false, this.advance30 = false, this.maxSnooze = 3, this.sound = 'default'});
  factory _AlarmConfig.fromJson(Map<String, dynamic> json) => _$AlarmConfigFromJson(json);

/// 是否启用
@override@JsonKey() final  bool enabled;
/// 提醒时间 HH:mm
@override@JsonKey() final  String time;
/// 提前 15 分钟提醒
@override@JsonKey() final  bool advance15;
/// 提前 30 分钟提醒
@override@JsonKey() final  bool advance30;
/// 贪睡最大次数（最多 3 次）
@override@JsonKey() final  int maxSnooze;
/// 铃音 id（内置 3-5 首轻柔纯音乐 / 本地音频路径）
@override@JsonKey() final  String sound;

/// Create a copy of AlarmConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlarmConfigCopyWith<_AlarmConfig> get copyWith => __$AlarmConfigCopyWithImpl<_AlarmConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlarmConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlarmConfig&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.time, time) || other.time == time)&&(identical(other.advance15, advance15) || other.advance15 == advance15)&&(identical(other.advance30, advance30) || other.advance30 == advance30)&&(identical(other.maxSnooze, maxSnooze) || other.maxSnooze == maxSnooze)&&(identical(other.sound, sound) || other.sound == sound));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,enabled,time,advance15,advance30,maxSnooze,sound);
}

@override
String toString() {
    return 'AlarmConfig(enabled: $enabled, time: $time, advance15: $advance15, advance30: $advance30, maxSnooze: $maxSnooze, sound: $sound)';
}


}

/// @nodoc
abstract mixin class _$AlarmConfigCopyWith<$Res> implements $AlarmConfigCopyWith<$Res> {
  factory _$AlarmConfigCopyWith(_AlarmConfig value, $Res Function(_AlarmConfig) _then) = __$AlarmConfigCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, String time, bool advance15, bool advance30, int maxSnooze, String sound
});




}
/// @nodoc
class __$AlarmConfigCopyWithImpl<$Res>
    implements _$AlarmConfigCopyWith<$Res> {
  __$AlarmConfigCopyWithImpl(this._self, this._then);

  final _AlarmConfig _self;
  final $Res Function(_AlarmConfig) _then;

/// Create a copy of AlarmConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? time = null,Object? advance15 = null,Object? advance30 = null,Object? maxSnooze = null,Object? sound = null,}) {
  return _then(_AlarmConfig(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,advance15: null == advance15 ? _self.advance15 : advance15 // ignore: cast_nullable_to_non_nullable
as bool,advance30: null == advance30 ? _self.advance30 : advance30 // ignore: cast_nullable_to_non_nullable
as bool,maxSnooze: null == maxSnooze ? _self.maxSnooze : maxSnooze // ignore: cast_nullable_to_non_nullable
as int,sound: null == sound ? _self.sound : sound // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
