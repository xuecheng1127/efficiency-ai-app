// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppSettings {
  /// 主题模式（默认跟随系统）
  ThemeMode get themeMode;

  /// 任务提醒总开关（默认开启）
  bool get taskReminderEnabled;

  /// 新任务默认重复规则（0=单次 1=每日 2=每周）
  int get defaultRepeatRule;

  /// 闹钟铃音名称
  String get alarmRingtone;

  /// 闹钟音量（0-100）
  int get alarmVolume;

  /// 贪睡模式开关
  bool get snoozeEnabled;

  /// 贪睡间隔（分钟）
  int get snoozeMinutes;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AppSettingsCopyWith<AppSettings> get copyWith =>
      _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);

  /// Serializes this AppSettings to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    final _this = this as AppSettings;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AppSettings &&
            (identical(other.themeMode, _this.themeMode) ||
                other.themeMode == _this.themeMode) &&
            (identical(other.taskReminderEnabled, _this.taskReminderEnabled) ||
                other.taskReminderEnabled == _this.taskReminderEnabled) &&
            (identical(other.defaultRepeatRule, _this.defaultRepeatRule) ||
                other.defaultRepeatRule == _this.defaultRepeatRule) &&
            (identical(other.alarmRingtone, _this.alarmRingtone) ||
                other.alarmRingtone == _this.alarmRingtone) &&
            (identical(other.alarmVolume, _this.alarmVolume) ||
                other.alarmVolume == _this.alarmVolume) &&
            (identical(other.snoozeEnabled, _this.snoozeEnabled) ||
                other.snoozeEnabled == _this.snoozeEnabled) &&
            (identical(other.snoozeMinutes, _this.snoozeMinutes) ||
                other.snoozeMinutes == _this.snoozeMinutes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    final _this = this as AppSettings;
    return Object.hash(
        runtimeType,
        _this.themeMode,
        _this.taskReminderEnabled,
        _this.defaultRepeatRule,
        _this.alarmRingtone,
        _this.alarmVolume,
        _this.snoozeEnabled,
        _this.snoozeMinutes);
  }

  @override
  String toString() {
    final _this = this as AppSettings;
    return 'AppSettings(themeMode: ${_this.themeMode}, taskReminderEnabled: ${_this.taskReminderEnabled}, defaultRepeatRule: ${_this.defaultRepeatRule}, alarmRingtone: ${_this.alarmRingtone}, alarmVolume: ${_this.alarmVolume}, snoozeEnabled: ${_this.snoozeEnabled}, snoozeMinutes: ${_this.snoozeMinutes})';
  }
}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res> {
  factory $AppSettingsCopyWith(
          AppSettings value, $Res Function(AppSettings) _then) =
      _$AppSettingsCopyWithImpl;
  @useResult
  $Res call(
      {ThemeMode themeMode,
      bool taskReminderEnabled,
      int defaultRepeatRule,
      String alarmRingtone,
      int alarmVolume,
      bool snoozeEnabled,
      int snoozeMinutes});
}

/// @nodoc
class _$AppSettingsCopyWithImpl<$Res> implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? themeMode = null,
    Object? taskReminderEnabled = null,
    Object? defaultRepeatRule = null,
    Object? alarmRingtone = null,
    Object? alarmVolume = null,
    Object? snoozeEnabled = null,
    Object? snoozeMinutes = null,
  }) {
    return _then(AppSettings(
      themeMode: null == themeMode
          ? _self.themeMode
          : themeMode // ignore: cast_nullable_to_non_nullable
              as ThemeMode,
      taskReminderEnabled: null == taskReminderEnabled
          ? _self.taskReminderEnabled
          : taskReminderEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      defaultRepeatRule: null == defaultRepeatRule
          ? _self.defaultRepeatRule
          : defaultRepeatRule // ignore: cast_nullable_to_non_nullable
              as int,
      alarmRingtone: null == alarmRingtone
          ? _self.alarmRingtone
          : alarmRingtone // ignore: cast_nullable_to_non_nullable
              as String,
      alarmVolume: null == alarmVolume
          ? _self.alarmVolume
          : alarmVolume // ignore: cast_nullable_to_non_nullable
              as int,
      snoozeEnabled: null == snoozeEnabled
          ? _self.snoozeEnabled
          : snoozeEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      snoozeMinutes: null == snoozeMinutes
          ? _self.snoozeMinutes
          : snoozeMinutes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_AppSettings value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AppSettings() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_AppSettings value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AppSettings():
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_AppSettings value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AppSettings() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            ThemeMode themeMode,
            bool taskReminderEnabled,
            int defaultRepeatRule,
            String alarmRingtone,
            int alarmVolume,
            bool snoozeEnabled,
            int snoozeMinutes)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AppSettings() when $default != null:
        return $default(
            _that.themeMode,
            _that.taskReminderEnabled,
            _that.defaultRepeatRule,
            _that.alarmRingtone,
            _that.alarmVolume,
            _that.snoozeEnabled,
            _that.snoozeMinutes);
      case _:
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

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            ThemeMode themeMode,
            bool taskReminderEnabled,
            int defaultRepeatRule,
            String alarmRingtone,
            int alarmVolume,
            bool snoozeEnabled,
            int snoozeMinutes)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AppSettings():
        return $default(
            _that.themeMode,
            _that.taskReminderEnabled,
            _that.defaultRepeatRule,
            _that.alarmRingtone,
            _that.alarmVolume,
            _that.snoozeEnabled,
            _that.snoozeMinutes);
      case _:
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

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            ThemeMode themeMode,
            bool taskReminderEnabled,
            int defaultRepeatRule,
            String alarmRingtone,
            int alarmVolume,
            bool snoozeEnabled,
            int snoozeMinutes)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AppSettings() when $default != null:
        return $default(
            _that.themeMode,
            _that.taskReminderEnabled,
            _that.defaultRepeatRule,
            _that.alarmRingtone,
            _that.alarmVolume,
            _that.snoozeEnabled,
            _that.snoozeMinutes);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AppSettings implements AppSettings {
  const _AppSettings(
      {this.themeMode = ThemeMode.system,
      this.taskReminderEnabled = true,
      this.defaultRepeatRule = 0,
      this.alarmRingtone = '内置·晨曦',
      this.alarmVolume = 80,
      this.snoozeEnabled = true,
      this.snoozeMinutes = 5});
  factory _AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  /// 主题模式（默认跟随系统）
  @override
  @JsonKey()
  final ThemeMode themeMode;

  /// 任务提醒总开关（默认开启）
  @override
  @JsonKey()
  final bool taskReminderEnabled;

  /// 新任务默认重复规则（0=单次 1=每日 2=每周）
  @override
  @JsonKey()
  final int defaultRepeatRule;

  /// 闹钟铃音名称
  @override
  @JsonKey()
  final String alarmRingtone;

  /// 闹钟音量（0-100）
  @override
  @JsonKey()
  final int alarmVolume;

  /// 贪睡模式开关
  @override
  @JsonKey()
  final bool snoozeEnabled;

  /// 贪睡间隔（分钟）
  @override
  @JsonKey()
  final int snoozeMinutes;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AppSettingsCopyWith<_AppSettings> get copyWith =>
      __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AppSettingsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AppSettings &&
            (identical(other.themeMode, themeMode) ||
                other.themeMode == themeMode) &&
            (identical(other.taskReminderEnabled, taskReminderEnabled) ||
                other.taskReminderEnabled == taskReminderEnabled) &&
            (identical(other.defaultRepeatRule, defaultRepeatRule) ||
                other.defaultRepeatRule == defaultRepeatRule) &&
            (identical(other.alarmRingtone, alarmRingtone) ||
                other.alarmRingtone == alarmRingtone) &&
            (identical(other.alarmVolume, alarmVolume) ||
                other.alarmVolume == alarmVolume) &&
            (identical(other.snoozeEnabled, snoozeEnabled) ||
                other.snoozeEnabled == snoozeEnabled) &&
            (identical(other.snoozeMinutes, snoozeMinutes) ||
                other.snoozeMinutes == snoozeMinutes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode {
    return Object.hash(
        runtimeType,
        themeMode,
        taskReminderEnabled,
        defaultRepeatRule,
        alarmRingtone,
        alarmVolume,
        snoozeEnabled,
        snoozeMinutes);
  }

  @override
  String toString() {
    return 'AppSettings(themeMode: $themeMode, taskReminderEnabled: $taskReminderEnabled, defaultRepeatRule: $defaultRepeatRule, alarmRingtone: $alarmRingtone, alarmVolume: $alarmVolume, snoozeEnabled: $snoozeEnabled, snoozeMinutes: $snoozeMinutes)';
  }
}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res>
    implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(
          _AppSettings value, $Res Function(_AppSettings) _then) =
      __$AppSettingsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {ThemeMode themeMode,
      bool taskReminderEnabled,
      int defaultRepeatRule,
      String alarmRingtone,
      int alarmVolume,
      bool snoozeEnabled,
      int snoozeMinutes});
}

/// @nodoc
class __$AppSettingsCopyWithImpl<$Res> implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? themeMode = null,
    Object? taskReminderEnabled = null,
    Object? defaultRepeatRule = null,
    Object? alarmRingtone = null,
    Object? alarmVolume = null,
    Object? snoozeEnabled = null,
    Object? snoozeMinutes = null,
  }) {
    return _then(_AppSettings(
      themeMode: null == themeMode
          ? _self.themeMode
          : themeMode // ignore: cast_nullable_to_non_nullable
              as ThemeMode,
      taskReminderEnabled: null == taskReminderEnabled
          ? _self.taskReminderEnabled
          : taskReminderEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      defaultRepeatRule: null == defaultRepeatRule
          ? _self.defaultRepeatRule
          : defaultRepeatRule // ignore: cast_nullable_to_non_nullable
              as int,
      alarmRingtone: null == alarmRingtone
          ? _self.alarmRingtone
          : alarmRingtone // ignore: cast_nullable_to_non_nullable
              as String,
      alarmVolume: null == alarmVolume
          ? _self.alarmVolume
          : alarmVolume // ignore: cast_nullable_to_non_nullable
              as int,
      snoozeEnabled: null == snoozeEnabled
          ? _self.snoozeEnabled
          : snoozeEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      snoozeMinutes: null == snoozeMinutes
          ? _self.snoozeMinutes
          : snoozeMinutes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
