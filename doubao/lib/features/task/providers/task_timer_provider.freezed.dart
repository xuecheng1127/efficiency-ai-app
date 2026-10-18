// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_timer_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskTimerState {
  /// 当前计时中的任务实例 id；-1 表示空闲
  int get occurrenceId;

  /// 任务标题（通知栏/横幅展示）
  String get title;

  /// 本次计时起点（数据库 startedAt，持久化保证跨启动恢复）
  DateTime? get startedAt;

  /// 本次计时开始前已累计秒数（数据库 durationSeconds 快照）
  int get baseSeconds;

  /// 最新累计秒数（baseSeconds + 已流逝秒，每秒心跳刷新）
  int get elapsedSeconds;

  /// 前台服务是否已启动
  bool get serviceStarted;

  /// Create a copy of TaskTimerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskTimerStateCopyWith<TaskTimerState> get copyWith =>
      _$TaskTimerStateCopyWithImpl<TaskTimerState>(
          this as TaskTimerState, _$identity);

  @override
  bool operator ==(Object other) {
    final _this = this as TaskTimerState;
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskTimerState &&
            (identical(other.occurrenceId, _this.occurrenceId) ||
                other.occurrenceId == _this.occurrenceId) &&
            (identical(other.title, _this.title) ||
                other.title == _this.title) &&
            (identical(other.startedAt, _this.startedAt) ||
                other.startedAt == _this.startedAt) &&
            (identical(other.baseSeconds, _this.baseSeconds) ||
                other.baseSeconds == _this.baseSeconds) &&
            (identical(other.elapsedSeconds, _this.elapsedSeconds) ||
                other.elapsedSeconds == _this.elapsedSeconds) &&
            (identical(other.serviceStarted, _this.serviceStarted) ||
                other.serviceStarted == _this.serviceStarted));
  }

  @override
  int get hashCode {
    final _this = this as TaskTimerState;
    return Object.hash(
        runtimeType,
        _this.occurrenceId,
        _this.title,
        _this.startedAt,
        _this.baseSeconds,
        _this.elapsedSeconds,
        _this.serviceStarted);
  }

  @override
  String toString() {
    final _this = this as TaskTimerState;
    return 'TaskTimerState(occurrenceId: ${_this.occurrenceId}, title: ${_this.title}, startedAt: ${_this.startedAt}, baseSeconds: ${_this.baseSeconds}, elapsedSeconds: ${_this.elapsedSeconds}, serviceStarted: ${_this.serviceStarted})';
  }
}

/// @nodoc
abstract mixin class $TaskTimerStateCopyWith<$Res> {
  factory $TaskTimerStateCopyWith(
          TaskTimerState value, $Res Function(TaskTimerState) _then) =
      _$TaskTimerStateCopyWithImpl;
  @useResult
  $Res call(
      {int occurrenceId,
      String title,
      DateTime? startedAt,
      int baseSeconds,
      int elapsedSeconds,
      bool serviceStarted});
}

/// @nodoc
class _$TaskTimerStateCopyWithImpl<$Res>
    implements $TaskTimerStateCopyWith<$Res> {
  _$TaskTimerStateCopyWithImpl(this._self, this._then);

  final TaskTimerState _self;
  final $Res Function(TaskTimerState) _then;

  /// Create a copy of TaskTimerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? occurrenceId = null,
    Object? title = null,
    Object? startedAt = freezed,
    Object? baseSeconds = null,
    Object? elapsedSeconds = null,
    Object? serviceStarted = null,
  }) {
    return _then(TaskTimerState(
      occurrenceId: null == occurrenceId
          ? _self.occurrenceId
          : occurrenceId // ignore: cast_nullable_to_non_nullable
              as int,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: freezed == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      baseSeconds: null == baseSeconds
          ? _self.baseSeconds
          : baseSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      elapsedSeconds: null == elapsedSeconds
          ? _self.elapsedSeconds
          : elapsedSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      serviceStarted: null == serviceStarted
          ? _self.serviceStarted
          : serviceStarted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [TaskTimerState].
extension TaskTimerStatePatterns on TaskTimerState {
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
    TResult Function(_TaskTimerState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskTimerState() when $default != null:
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
    TResult Function(_TaskTimerState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskTimerState():
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
    TResult? Function(_TaskTimerState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskTimerState() when $default != null:
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
    TResult Function(int occurrenceId, String title, DateTime? startedAt,
            int baseSeconds, int elapsedSeconds, bool serviceStarted)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskTimerState() when $default != null:
        return $default(_that.occurrenceId, _that.title, _that.startedAt,
            _that.baseSeconds, _that.elapsedSeconds, _that.serviceStarted);
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
    TResult Function(int occurrenceId, String title, DateTime? startedAt,
            int baseSeconds, int elapsedSeconds, bool serviceStarted)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskTimerState():
        return $default(_that.occurrenceId, _that.title, _that.startedAt,
            _that.baseSeconds, _that.elapsedSeconds, _that.serviceStarted);
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
    TResult? Function(int occurrenceId, String title, DateTime? startedAt,
            int baseSeconds, int elapsedSeconds, bool serviceStarted)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskTimerState() when $default != null:
        return $default(_that.occurrenceId, _that.title, _that.startedAt,
            _that.baseSeconds, _that.elapsedSeconds, _that.serviceStarted);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TaskTimerState extends TaskTimerState {
  const _TaskTimerState(
      {this.occurrenceId = -1,
      this.title = '',
      this.startedAt,
      this.baseSeconds = 0,
      this.elapsedSeconds = 0,
      this.serviceStarted = false})
      : super._();

  /// 当前计时中的任务实例 id；-1 表示空闲
  @override
  @JsonKey()
  final int occurrenceId;

  /// 任务标题（通知栏/横幅展示）
  @override
  @JsonKey()
  final String title;

  /// 本次计时起点（数据库 startedAt，持久化保证跨启动恢复）
  @override
  final DateTime? startedAt;

  /// 本次计时开始前已累计秒数（数据库 durationSeconds 快照）
  @override
  @JsonKey()
  final int baseSeconds;

  /// 最新累计秒数（baseSeconds + 已流逝秒，每秒心跳刷新）
  @override
  @JsonKey()
  final int elapsedSeconds;

  /// 前台服务是否已启动
  @override
  @JsonKey()
  final bool serviceStarted;

  /// Create a copy of TaskTimerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TaskTimerStateCopyWith<_TaskTimerState> get copyWith =>
      __$TaskTimerStateCopyWithImpl<_TaskTimerState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TaskTimerState &&
            (identical(other.occurrenceId, occurrenceId) ||
                other.occurrenceId == occurrenceId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.baseSeconds, baseSeconds) ||
                other.baseSeconds == baseSeconds) &&
            (identical(other.elapsedSeconds, elapsedSeconds) ||
                other.elapsedSeconds == elapsedSeconds) &&
            (identical(other.serviceStarted, serviceStarted) ||
                other.serviceStarted == serviceStarted));
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, occurrenceId, title, startedAt, baseSeconds,
        elapsedSeconds, serviceStarted);
  }

  @override
  String toString() {
    return 'TaskTimerState(occurrenceId: $occurrenceId, title: $title, startedAt: $startedAt, baseSeconds: $baseSeconds, elapsedSeconds: $elapsedSeconds, serviceStarted: $serviceStarted)';
  }
}

/// @nodoc
abstract mixin class _$TaskTimerStateCopyWith<$Res>
    implements $TaskTimerStateCopyWith<$Res> {
  factory _$TaskTimerStateCopyWith(
          _TaskTimerState value, $Res Function(_TaskTimerState) _then) =
      __$TaskTimerStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int occurrenceId,
      String title,
      DateTime? startedAt,
      int baseSeconds,
      int elapsedSeconds,
      bool serviceStarted});
}

/// @nodoc
class __$TaskTimerStateCopyWithImpl<$Res>
    implements _$TaskTimerStateCopyWith<$Res> {
  __$TaskTimerStateCopyWithImpl(this._self, this._then);

  final _TaskTimerState _self;
  final $Res Function(_TaskTimerState) _then;

  /// Create a copy of TaskTimerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? occurrenceId = null,
    Object? title = null,
    Object? startedAt = freezed,
    Object? baseSeconds = null,
    Object? elapsedSeconds = null,
    Object? serviceStarted = null,
  }) {
    return _then(_TaskTimerState(
      occurrenceId: null == occurrenceId
          ? _self.occurrenceId
          : occurrenceId // ignore: cast_nullable_to_non_nullable
              as int,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      startedAt: freezed == startedAt
          ? _self.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      baseSeconds: null == baseSeconds
          ? _self.baseSeconds
          : baseSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      elapsedSeconds: null == elapsedSeconds
          ? _self.elapsedSeconds
          : elapsedSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      serviceStarted: null == serviceStarted
          ? _self.serviceStarted
          : serviceStarted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
