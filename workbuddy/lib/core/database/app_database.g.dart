// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TaskTemplatesTable extends TaskTemplates
    with TableInfo<$TaskTemplatesTable, TaskTemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatModeMeta = const VerificationMeta(
    'repeatMode',
  );
  @override
  late final GeneratedColumn<String> repeatMode = GeneratedColumn<String>(
    'repeat_mode',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatDaysMeta = const VerificationMeta(
    'repeatDays',
  );
  @override
  late final GeneratedColumn<String> repeatDays = GeneratedColumn<String>(
    'repeat_days',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinutesBeforeMeta =
      const VerificationMeta('reminderMinutesBefore');
  @override
  late final GeneratedColumn<int> reminderMinutesBefore = GeneratedColumn<int>(
    'reminder_minutes_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alarmEnabledMeta = const VerificationMeta(
    'alarmEnabled',
  );
  @override
  late final GeneratedColumn<bool> alarmEnabled = GeneratedColumn<bool>(
    'alarm_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("alarm_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _alarmConfigJsonMeta = const VerificationMeta(
    'alarmConfigJson',
  );
  @override
  late final GeneratedColumn<String> alarmConfigJson = GeneratedColumn<String>(
    'alarm_config_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caloriePerMinuteMeta = const VerificationMeta(
    'caloriePerMinute',
  );
  @override
  late final GeneratedColumn<double> caloriePerMinute = GeneratedColumn<double>(
    'calorie_per_minute',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    repeatMode,
    repeatDays,
    startDate,
    endDate,
    reminderMinutesBefore,
    alarmEnabled,
    alarmConfigJson,
    caloriePerMinute,
    archivedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskTemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('repeat_mode')) {
      context.handle(
        _repeatModeMeta,
        repeatMode.isAcceptableOrUnknown(data['repeat_mode']!, _repeatModeMeta),
      );
    } else if (isInserting) {
      context.missing(_repeatModeMeta);
    }
    if (data.containsKey('repeat_days')) {
      context.handle(
        _repeatDaysMeta,
        repeatDays.isAcceptableOrUnknown(data['repeat_days']!, _repeatDaysMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('reminder_minutes_before')) {
      context.handle(
        _reminderMinutesBeforeMeta,
        reminderMinutesBefore.isAcceptableOrUnknown(
          data['reminder_minutes_before']!,
          _reminderMinutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('alarm_enabled')) {
      context.handle(
        _alarmEnabledMeta,
        alarmEnabled.isAcceptableOrUnknown(
          data['alarm_enabled']!,
          _alarmEnabledMeta,
        ),
      );
    }
    if (data.containsKey('alarm_config_json')) {
      context.handle(
        _alarmConfigJsonMeta,
        alarmConfigJson.isAcceptableOrUnknown(
          data['alarm_config_json']!,
          _alarmConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('calorie_per_minute')) {
      context.handle(
        _caloriePerMinuteMeta,
        caloriePerMinute.isAcceptableOrUnknown(
          data['calorie_per_minute']!,
          _caloriePerMinuteMeta,
        ),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskTemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      repeatMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_mode'],
      )!,
      repeatDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_days'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      reminderMinutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes_before'],
      ),
      alarmEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}alarm_enabled'],
      )!,
      alarmConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm_config_json'],
      ),
      caloriePerMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}calorie_per_minute'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TaskTemplatesTable createAlias(String alias) {
    return $TaskTemplatesTable(attachedDatabase, alias);
  }
}

class TaskTemplateRow extends DataClass implements Insertable<TaskTemplateRow> {
  final int id;

  /// 任务类型：fitness | study
  final String type;

  /// 标题（长度 1–200）
  final String title;

  /// 重复模式：once | daily | weekly
  final String repeatMode;

  /// 仅 weekly："1,3,5"（1=周一 … 7=周日，Dart 语义）
  final String? repeatDays;

  /// 生效起始日（once 时即执行日）
  final DateTime startDate;

  /// NULL = 无限
  final DateTime? endDate;

  /// 提前提醒分钟数：15 / 30；NULL = 不提醒
  final int? reminderMinutesBefore;

  /// 闹钟开关（0/1，底层 INTEGER）
  final bool alarmEnabled;

  /// 铃声、渐强、贪睡次数等（JSON）
  final String? alarmConfigJson;

  /// 仅 fitness：千卡/分钟
  final double? caloriePerMinute;

  /// 模板级软删除（停止重复，保留历史实例）
  final DateTime? archivedAt;
  final DateTime createdAt;
  const TaskTemplateRow({
    required this.id,
    required this.type,
    required this.title,
    required this.repeatMode,
    this.repeatDays,
    required this.startDate,
    this.endDate,
    this.reminderMinutesBefore,
    required this.alarmEnabled,
    this.alarmConfigJson,
    this.caloriePerMinute,
    this.archivedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['repeat_mode'] = Variable<String>(repeatMode);
    if (!nullToAbsent || repeatDays != null) {
      map['repeat_days'] = Variable<String>(repeatDays);
    }
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || reminderMinutesBefore != null) {
      map['reminder_minutes_before'] = Variable<int>(reminderMinutesBefore);
    }
    map['alarm_enabled'] = Variable<bool>(alarmEnabled);
    if (!nullToAbsent || alarmConfigJson != null) {
      map['alarm_config_json'] = Variable<String>(alarmConfigJson);
    }
    if (!nullToAbsent || caloriePerMinute != null) {
      map['calorie_per_minute'] = Variable<double>(caloriePerMinute);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TaskTemplatesCompanion toCompanion(bool nullToAbsent) {
    return TaskTemplatesCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      repeatMode: Value(repeatMode),
      repeatDays: repeatDays == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatDays),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      reminderMinutesBefore: reminderMinutesBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutesBefore),
      alarmEnabled: Value(alarmEnabled),
      alarmConfigJson: alarmConfigJson == null && nullToAbsent
          ? const Value.absent()
          : Value(alarmConfigJson),
      caloriePerMinute: caloriePerMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(caloriePerMinute),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
    );
  }

  factory TaskTemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTemplateRow(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      repeatMode: serializer.fromJson<String>(json['repeatMode']),
      repeatDays: serializer.fromJson<String?>(json['repeatDays']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      reminderMinutesBefore: serializer.fromJson<int?>(
        json['reminderMinutesBefore'],
      ),
      alarmEnabled: serializer.fromJson<bool>(json['alarmEnabled']),
      alarmConfigJson: serializer.fromJson<String?>(json['alarmConfigJson']),
      caloriePerMinute: serializer.fromJson<double?>(json['caloriePerMinute']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'repeatMode': serializer.toJson<String>(repeatMode),
      'repeatDays': serializer.toJson<String?>(repeatDays),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'reminderMinutesBefore': serializer.toJson<int?>(reminderMinutesBefore),
      'alarmEnabled': serializer.toJson<bool>(alarmEnabled),
      'alarmConfigJson': serializer.toJson<String?>(alarmConfigJson),
      'caloriePerMinute': serializer.toJson<double?>(caloriePerMinute),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TaskTemplateRow copyWith({
    int? id,
    String? type,
    String? title,
    String? repeatMode,
    Value<String?> repeatDays = const Value.absent(),
    DateTime? startDate,
    Value<DateTime?> endDate = const Value.absent(),
    Value<int?> reminderMinutesBefore = const Value.absent(),
    bool? alarmEnabled,
    Value<String?> alarmConfigJson = const Value.absent(),
    Value<double?> caloriePerMinute = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
  }) => TaskTemplateRow(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    repeatMode: repeatMode ?? this.repeatMode,
    repeatDays: repeatDays.present ? repeatDays.value : this.repeatDays,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    reminderMinutesBefore: reminderMinutesBefore.present
        ? reminderMinutesBefore.value
        : this.reminderMinutesBefore,
    alarmEnabled: alarmEnabled ?? this.alarmEnabled,
    alarmConfigJson: alarmConfigJson.present
        ? alarmConfigJson.value
        : this.alarmConfigJson,
    caloriePerMinute: caloriePerMinute.present
        ? caloriePerMinute.value
        : this.caloriePerMinute,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TaskTemplateRow copyWithCompanion(TaskTemplatesCompanion data) {
    return TaskTemplateRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      repeatMode: data.repeatMode.present
          ? data.repeatMode.value
          : this.repeatMode,
      repeatDays: data.repeatDays.present
          ? data.repeatDays.value
          : this.repeatDays,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      reminderMinutesBefore: data.reminderMinutesBefore.present
          ? data.reminderMinutesBefore.value
          : this.reminderMinutesBefore,
      alarmEnabled: data.alarmEnabled.present
          ? data.alarmEnabled.value
          : this.alarmEnabled,
      alarmConfigJson: data.alarmConfigJson.present
          ? data.alarmConfigJson.value
          : this.alarmConfigJson,
      caloriePerMinute: data.caloriePerMinute.present
          ? data.caloriePerMinute.value
          : this.caloriePerMinute,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTemplateRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('repeatDays: $repeatDays, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('alarmEnabled: $alarmEnabled, ')
          ..write('alarmConfigJson: $alarmConfigJson, ')
          ..write('caloriePerMinute: $caloriePerMinute, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    repeatMode,
    repeatDays,
    startDate,
    endDate,
    reminderMinutesBefore,
    alarmEnabled,
    alarmConfigJson,
    caloriePerMinute,
    archivedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTemplateRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.repeatMode == this.repeatMode &&
          other.repeatDays == this.repeatDays &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.reminderMinutesBefore == this.reminderMinutesBefore &&
          other.alarmEnabled == this.alarmEnabled &&
          other.alarmConfigJson == this.alarmConfigJson &&
          other.caloriePerMinute == this.caloriePerMinute &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt);
}

class TaskTemplatesCompanion extends UpdateCompanion<TaskTemplateRow> {
  final Value<int> id;
  final Value<String> type;
  final Value<String> title;
  final Value<String> repeatMode;
  final Value<String?> repeatDays;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<int?> reminderMinutesBefore;
  final Value<bool> alarmEnabled;
  final Value<String?> alarmConfigJson;
  final Value<double?> caloriePerMinute;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  const TaskTemplatesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.repeatMode = const Value.absent(),
    this.repeatDays = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.alarmEnabled = const Value.absent(),
    this.alarmConfigJson = const Value.absent(),
    this.caloriePerMinute = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TaskTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required String title,
    required String repeatMode,
    this.repeatDays = const Value.absent(),
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.alarmEnabled = const Value.absent(),
    this.alarmConfigJson = const Value.absent(),
    this.caloriePerMinute = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : type = Value(type),
       title = Value(title),
       repeatMode = Value(repeatMode),
       startDate = Value(startDate);
  static Insertable<TaskTemplateRow> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? repeatMode,
    Expression<String>? repeatDays,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? reminderMinutesBefore,
    Expression<bool>? alarmEnabled,
    Expression<String>? alarmConfigJson,
    Expression<double>? caloriePerMinute,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (repeatMode != null) 'repeat_mode': repeatMode,
      if (repeatDays != null) 'repeat_days': repeatDays,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (reminderMinutesBefore != null)
        'reminder_minutes_before': reminderMinutesBefore,
      if (alarmEnabled != null) 'alarm_enabled': alarmEnabled,
      if (alarmConfigJson != null) 'alarm_config_json': alarmConfigJson,
      if (caloriePerMinute != null) 'calorie_per_minute': caloriePerMinute,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TaskTemplatesCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String>? title,
    Value<String>? repeatMode,
    Value<String?>? repeatDays,
    Value<DateTime>? startDate,
    Value<DateTime?>? endDate,
    Value<int?>? reminderMinutesBefore,
    Value<bool>? alarmEnabled,
    Value<String?>? alarmConfigJson,
    Value<double?>? caloriePerMinute,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
  }) {
    return TaskTemplatesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      repeatMode: repeatMode ?? this.repeatMode,
      repeatDays: repeatDays ?? this.repeatDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmConfigJson: alarmConfigJson ?? this.alarmConfigJson,
      caloriePerMinute: caloriePerMinute ?? this.caloriePerMinute,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (repeatMode.present) {
      map['repeat_mode'] = Variable<String>(repeatMode.value);
    }
    if (repeatDays.present) {
      map['repeat_days'] = Variable<String>(repeatDays.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (reminderMinutesBefore.present) {
      map['reminder_minutes_before'] = Variable<int>(
        reminderMinutesBefore.value,
      );
    }
    if (alarmEnabled.present) {
      map['alarm_enabled'] = Variable<bool>(alarmEnabled.value);
    }
    if (alarmConfigJson.present) {
      map['alarm_config_json'] = Variable<String>(alarmConfigJson.value);
    }
    if (caloriePerMinute.present) {
      map['calorie_per_minute'] = Variable<double>(caloriePerMinute.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('repeatMode: $repeatMode, ')
          ..write('repeatDays: $repeatDays, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('alarmEnabled: $alarmEnabled, ')
          ..write('alarmConfigJson: $alarmConfigJson, ')
          ..write('caloriePerMinute: $caloriePerMinute, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TaskInstancesTable extends TaskInstances
    with TableInfo<$TaskInstancesTable, TaskInstanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskInstancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<int> templateId = GeneratedColumn<int>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_templates (id)',
    ),
  );
  static const VerificationMeta _occurrenceDateMeta = const VerificationMeta(
    'occurrenceDate',
  );
  @override
  late final GeneratedColumn<DateTime> occurrenceDate =
      GeneratedColumn<DateTime>(
        'occurrence_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _titleSnapshotMeta = const VerificationMeta(
    'titleSnapshot',
  );
  @override
  late final GeneratedColumn<String> titleSnapshot = GeneratedColumn<String>(
    'title_snapshot',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeSnapshotMeta = const VerificationMeta(
    'typeSnapshot',
  );
  @override
  late final GeneratedColumn<String> typeSnapshot = GeneratedColumn<String>(
    'type_snapshot',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caloriePerMinuteSnapshotMeta =
      const VerificationMeta('caloriePerMinuteSnapshot');
  @override
  late final GeneratedColumn<double> caloriePerMinuteSnapshot =
      GeneratedColumn<double>(
        'calorie_per_minute_snapshot',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accumulatedSecondsMeta =
      const VerificationMeta('accumulatedSeconds');
  @override
  late final GeneratedColumn<int> accumulatedSeconds = GeneratedColumn<int>(
    'accumulated_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateId,
    occurrenceDate,
    titleSnapshot,
    typeSnapshot,
    caloriePerMinuteSnapshot,
    status,
    startedAt,
    accumulatedSeconds,
    completedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_instances';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskInstanceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('occurrence_date')) {
      context.handle(
        _occurrenceDateMeta,
        occurrenceDate.isAcceptableOrUnknown(
          data['occurrence_date']!,
          _occurrenceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceDateMeta);
    }
    if (data.containsKey('title_snapshot')) {
      context.handle(
        _titleSnapshotMeta,
        titleSnapshot.isAcceptableOrUnknown(
          data['title_snapshot']!,
          _titleSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_titleSnapshotMeta);
    }
    if (data.containsKey('type_snapshot')) {
      context.handle(
        _typeSnapshotMeta,
        typeSnapshot.isAcceptableOrUnknown(
          data['type_snapshot']!,
          _typeSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_typeSnapshotMeta);
    }
    if (data.containsKey('calorie_per_minute_snapshot')) {
      context.handle(
        _caloriePerMinuteSnapshotMeta,
        caloriePerMinuteSnapshot.isAcceptableOrUnknown(
          data['calorie_per_minute_snapshot']!,
          _caloriePerMinuteSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('accumulated_seconds')) {
      context.handle(
        _accumulatedSecondsMeta,
        accumulatedSeconds.isAcceptableOrUnknown(
          data['accumulated_seconds']!,
          _accumulatedSecondsMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {templateId, occurrenceDate},
  ];
  @override
  TaskInstanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskInstanceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_id'],
      )!,
      occurrenceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurrence_date'],
      )!,
      titleSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_snapshot'],
      )!,
      typeSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_snapshot'],
      )!,
      caloriePerMinuteSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}calorie_per_minute_snapshot'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      accumulatedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accumulated_seconds'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TaskInstancesTable createAlias(String alias) {
    return $TaskInstancesTable(attachedDatabase, alias);
  }
}

class TaskInstanceRow extends DataClass implements Insertable<TaskInstanceRow> {
  final int id;

  /// 关联模板
  final int templateId;

  /// 该实例所属日期
  final DateTime occurrenceDate;

  /// 生成时的标题快照
  final String titleSnapshot;

  /// 类型快照
  final String typeSnapshot;

  /// 热量系数快照（仅 fitness）
  final double? caloriePerMinuteSnapshot;

  /// 三态：todo | inProgress | done
  final String status;

  /// 计时唯一真源
  final DateTime? startedAt;

  /// 已完成区段累计（秒）
  final int accumulatedSeconds;
  final DateTime? completedAt;

  /// 实例级软删除
  final DateTime? deletedAt;
  const TaskInstanceRow({
    required this.id,
    required this.templateId,
    required this.occurrenceDate,
    required this.titleSnapshot,
    required this.typeSnapshot,
    this.caloriePerMinuteSnapshot,
    required this.status,
    this.startedAt,
    required this.accumulatedSeconds,
    this.completedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['template_id'] = Variable<int>(templateId);
    map['occurrence_date'] = Variable<DateTime>(occurrenceDate);
    map['title_snapshot'] = Variable<String>(titleSnapshot);
    map['type_snapshot'] = Variable<String>(typeSnapshot);
    if (!nullToAbsent || caloriePerMinuteSnapshot != null) {
      map['calorie_per_minute_snapshot'] = Variable<double>(
        caloriePerMinuteSnapshot,
      );
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    map['accumulated_seconds'] = Variable<int>(accumulatedSeconds);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TaskInstancesCompanion toCompanion(bool nullToAbsent) {
    return TaskInstancesCompanion(
      id: Value(id),
      templateId: Value(templateId),
      occurrenceDate: Value(occurrenceDate),
      titleSnapshot: Value(titleSnapshot),
      typeSnapshot: Value(typeSnapshot),
      caloriePerMinuteSnapshot: caloriePerMinuteSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(caloriePerMinuteSnapshot),
      status: Value(status),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      accumulatedSeconds: Value(accumulatedSeconds),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TaskInstanceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskInstanceRow(
      id: serializer.fromJson<int>(json['id']),
      templateId: serializer.fromJson<int>(json['templateId']),
      occurrenceDate: serializer.fromJson<DateTime>(json['occurrenceDate']),
      titleSnapshot: serializer.fromJson<String>(json['titleSnapshot']),
      typeSnapshot: serializer.fromJson<String>(json['typeSnapshot']),
      caloriePerMinuteSnapshot: serializer.fromJson<double?>(
        json['caloriePerMinuteSnapshot'],
      ),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      accumulatedSeconds: serializer.fromJson<int>(json['accumulatedSeconds']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'templateId': serializer.toJson<int>(templateId),
      'occurrenceDate': serializer.toJson<DateTime>(occurrenceDate),
      'titleSnapshot': serializer.toJson<String>(titleSnapshot),
      'typeSnapshot': serializer.toJson<String>(typeSnapshot),
      'caloriePerMinuteSnapshot': serializer.toJson<double?>(
        caloriePerMinuteSnapshot,
      ),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'accumulatedSeconds': serializer.toJson<int>(accumulatedSeconds),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TaskInstanceRow copyWith({
    int? id,
    int? templateId,
    DateTime? occurrenceDate,
    String? titleSnapshot,
    String? typeSnapshot,
    Value<double?> caloriePerMinuteSnapshot = const Value.absent(),
    String? status,
    Value<DateTime?> startedAt = const Value.absent(),
    int? accumulatedSeconds,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => TaskInstanceRow(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    occurrenceDate: occurrenceDate ?? this.occurrenceDate,
    titleSnapshot: titleSnapshot ?? this.titleSnapshot,
    typeSnapshot: typeSnapshot ?? this.typeSnapshot,
    caloriePerMinuteSnapshot: caloriePerMinuteSnapshot.present
        ? caloriePerMinuteSnapshot.value
        : this.caloriePerMinuteSnapshot,
    status: status ?? this.status,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TaskInstanceRow copyWithCompanion(TaskInstancesCompanion data) {
    return TaskInstanceRow(
      id: data.id.present ? data.id.value : this.id,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      occurrenceDate: data.occurrenceDate.present
          ? data.occurrenceDate.value
          : this.occurrenceDate,
      titleSnapshot: data.titleSnapshot.present
          ? data.titleSnapshot.value
          : this.titleSnapshot,
      typeSnapshot: data.typeSnapshot.present
          ? data.typeSnapshot.value
          : this.typeSnapshot,
      caloriePerMinuteSnapshot: data.caloriePerMinuteSnapshot.present
          ? data.caloriePerMinuteSnapshot.value
          : this.caloriePerMinuteSnapshot,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      accumulatedSeconds: data.accumulatedSeconds.present
          ? data.accumulatedSeconds.value
          : this.accumulatedSeconds,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskInstanceRow(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('titleSnapshot: $titleSnapshot, ')
          ..write('typeSnapshot: $typeSnapshot, ')
          ..write('caloriePerMinuteSnapshot: $caloriePerMinuteSnapshot, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('accumulatedSeconds: $accumulatedSeconds, ')
          ..write('completedAt: $completedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    occurrenceDate,
    titleSnapshot,
    typeSnapshot,
    caloriePerMinuteSnapshot,
    status,
    startedAt,
    accumulatedSeconds,
    completedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskInstanceRow &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.occurrenceDate == this.occurrenceDate &&
          other.titleSnapshot == this.titleSnapshot &&
          other.typeSnapshot == this.typeSnapshot &&
          other.caloriePerMinuteSnapshot == this.caloriePerMinuteSnapshot &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.accumulatedSeconds == this.accumulatedSeconds &&
          other.completedAt == this.completedAt &&
          other.deletedAt == this.deletedAt);
}

class TaskInstancesCompanion extends UpdateCompanion<TaskInstanceRow> {
  final Value<int> id;
  final Value<int> templateId;
  final Value<DateTime> occurrenceDate;
  final Value<String> titleSnapshot;
  final Value<String> typeSnapshot;
  final Value<double?> caloriePerMinuteSnapshot;
  final Value<String> status;
  final Value<DateTime?> startedAt;
  final Value<int> accumulatedSeconds;
  final Value<DateTime?> completedAt;
  final Value<DateTime?> deletedAt;
  const TaskInstancesCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.titleSnapshot = const Value.absent(),
    this.typeSnapshot = const Value.absent(),
    this.caloriePerMinuteSnapshot = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.accumulatedSeconds = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TaskInstancesCompanion.insert({
    this.id = const Value.absent(),
    required int templateId,
    required DateTime occurrenceDate,
    required String titleSnapshot,
    required String typeSnapshot,
    this.caloriePerMinuteSnapshot = const Value.absent(),
    required String status,
    this.startedAt = const Value.absent(),
    this.accumulatedSeconds = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : templateId = Value(templateId),
       occurrenceDate = Value(occurrenceDate),
       titleSnapshot = Value(titleSnapshot),
       typeSnapshot = Value(typeSnapshot),
       status = Value(status);
  static Insertable<TaskInstanceRow> custom({
    Expression<int>? id,
    Expression<int>? templateId,
    Expression<DateTime>? occurrenceDate,
    Expression<String>? titleSnapshot,
    Expression<String>? typeSnapshot,
    Expression<double>? caloriePerMinuteSnapshot,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<int>? accumulatedSeconds,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (occurrenceDate != null) 'occurrence_date': occurrenceDate,
      if (titleSnapshot != null) 'title_snapshot': titleSnapshot,
      if (typeSnapshot != null) 'type_snapshot': typeSnapshot,
      if (caloriePerMinuteSnapshot != null)
        'calorie_per_minute_snapshot': caloriePerMinuteSnapshot,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (accumulatedSeconds != null) 'accumulated_seconds': accumulatedSeconds,
      if (completedAt != null) 'completed_at': completedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TaskInstancesCompanion copyWith({
    Value<int>? id,
    Value<int>? templateId,
    Value<DateTime>? occurrenceDate,
    Value<String>? titleSnapshot,
    Value<String>? typeSnapshot,
    Value<double?>? caloriePerMinuteSnapshot,
    Value<String>? status,
    Value<DateTime?>? startedAt,
    Value<int>? accumulatedSeconds,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return TaskInstancesCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      titleSnapshot: titleSnapshot ?? this.titleSnapshot,
      typeSnapshot: typeSnapshot ?? this.typeSnapshot,
      caloriePerMinuteSnapshot:
          caloriePerMinuteSnapshot ?? this.caloriePerMinuteSnapshot,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      completedAt: completedAt ?? this.completedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<int>(templateId.value);
    }
    if (occurrenceDate.present) {
      map['occurrence_date'] = Variable<DateTime>(occurrenceDate.value);
    }
    if (titleSnapshot.present) {
      map['title_snapshot'] = Variable<String>(titleSnapshot.value);
    }
    if (typeSnapshot.present) {
      map['type_snapshot'] = Variable<String>(typeSnapshot.value);
    }
    if (caloriePerMinuteSnapshot.present) {
      map['calorie_per_minute_snapshot'] = Variable<double>(
        caloriePerMinuteSnapshot.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (accumulatedSeconds.present) {
      map['accumulated_seconds'] = Variable<int>(accumulatedSeconds.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskInstancesCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('titleSnapshot: $titleSnapshot, ')
          ..write('typeSnapshot: $typeSnapshot, ')
          ..write('caloriePerMinuteSnapshot: $caloriePerMinuteSnapshot, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('accumulatedSeconds: $accumulatedSeconds, ')
          ..write('completedAt: $completedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $ScheduledAlarmsTable extends ScheduledAlarms
    with TableInfo<$ScheduledAlarmsTable, ScheduledAlarmRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledAlarmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES task_templates (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatRuleMeta = const VerificationMeta(
    'repeatRule',
  );
  @override
  late final GeneratedColumn<String> repeatRule = GeneratedColumn<String>(
    'repeat_rule',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekdaysMeta = const VerificationMeta(
    'weekdays',
  );
  @override
  late final GeneratedColumn<String> weekdays = GeneratedColumn<String>(
    'weekdays',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledDateMeta = const VerificationMeta(
    'scheduledDate',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledDate =
      GeneratedColumn<DateTime>(
        'scheduled_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _advanceMinutesMeta = const VerificationMeta(
    'advanceMinutes',
  );
  @override
  late final GeneratedColumn<int> advanceMinutes = GeneratedColumn<int>(
    'advance_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ringtoneMeta = const VerificationMeta(
    'ringtone',
  );
  @override
  late final GeneratedColumn<String> ringtone = GeneratedColumn<String>(
    'ringtone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<int> volume = GeneratedColumn<int>(
    'volume',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(80),
  );
  static const VerificationMeta _snoozeEnabledMeta = const VerificationMeta(
    'snoozeEnabled',
  );
  @override
  late final GeneratedColumn<bool> snoozeEnabled = GeneratedColumn<bool>(
    'snooze_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("snooze_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _snoozeMinutesMeta = const VerificationMeta(
    'snoozeMinutes',
  );
  @override
  late final GeneratedColumn<int> snoozeMinutes = GeneratedColumn<int>(
    'snooze_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('inexact'),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    hour,
    minute,
    repeatRule,
    weekdays,
    scheduledDate,
    advanceMinutes,
    ringtone,
    volume,
    snoozeEnabled,
    snoozeMinutes,
    tier,
    enabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_alarms';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledAlarmRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('repeat_rule')) {
      context.handle(
        _repeatRuleMeta,
        repeatRule.isAcceptableOrUnknown(data['repeat_rule']!, _repeatRuleMeta),
      );
    } else if (isInserting) {
      context.missing(_repeatRuleMeta);
    }
    if (data.containsKey('weekdays')) {
      context.handle(
        _weekdaysMeta,
        weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta),
      );
    }
    if (data.containsKey('scheduled_date')) {
      context.handle(
        _scheduledDateMeta,
        scheduledDate.isAcceptableOrUnknown(
          data['scheduled_date']!,
          _scheduledDateMeta,
        ),
      );
    }
    if (data.containsKey('advance_minutes')) {
      context.handle(
        _advanceMinutesMeta,
        advanceMinutes.isAcceptableOrUnknown(
          data['advance_minutes']!,
          _advanceMinutesMeta,
        ),
      );
    }
    if (data.containsKey('ringtone')) {
      context.handle(
        _ringtoneMeta,
        ringtone.isAcceptableOrUnknown(data['ringtone']!, _ringtoneMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('snooze_enabled')) {
      context.handle(
        _snoozeEnabledMeta,
        snoozeEnabled.isAcceptableOrUnknown(
          data['snooze_enabled']!,
          _snoozeEnabledMeta,
        ),
      );
    }
    if (data.containsKey('snooze_minutes')) {
      context.handle(
        _snoozeMinutesMeta,
        snoozeMinutes.isAcceptableOrUnknown(
          data['snooze_minutes']!,
          _snoozeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledAlarmRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledAlarmRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      )!,
      repeatRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule'],
      )!,
      weekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weekdays'],
      ),
      scheduledDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_date'],
      ),
      advanceMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}advance_minutes'],
      ),
      ringtone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ringtone'],
      )!,
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume'],
      )!,
      snoozeEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}snooze_enabled'],
      )!,
      snoozeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_minutes'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ScheduledAlarmsTable createAlias(String alias) {
    return $ScheduledAlarmsTable(attachedDatabase, alias);
  }
}

class ScheduledAlarmRow extends DataClass
    implements Insertable<ScheduledAlarmRow> {
  final int id;

  /// 关联任务模板 id（本工程双层模型里「绑定闹钟」落在模板粒度）。
  /// UNIQUE：一个任务至多一条持久化闹钟记录。
  final int taskId;

  /// 提醒时刻：小时 0–23
  final int hour;

  /// 提醒时刻：分钟 0–59
  final int minute;

  /// 重复规则：once | daily | weekly
  final String repeatRule;

  /// 仅 weekly："1,3,5"（1=周一 … 7=周日，Dart 语义）；其余为 NULL
  final String? weekdays;

  /// 仅 once 有意义：具体执行日（dateOnly，时分为 0）。
  /// 写入时 once 一律落成具体日期（未指定则取当天），重复任务通常为 NULL。
  final DateTime? scheduledDate;

  /// 提前提醒分钟数：15 / 30；NULL = 不提前
  final int? advanceMinutes;

  /// 铃音 id（内置曲目 id 或本地音频路径）
  final String ringtone;

  /// 音量百分比 0–100
  final int volume;

  /// 贪睡开关
  final bool snoozeEnabled;

  /// 贪睡间隔（分钟）
  final int snoozeMinutes;

  /// 当前档位：exact（A 精确档）| inexact（B 近似档）| inApp（C 应用内档）。
  /// T10 只负责「能存能读」，档位的判定与重排属于 T12。
  final String tier;

  /// 是否参与重建（关掉提醒 = 0，记录保留以便用户回看）。
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ScheduledAlarmRow({
    required this.id,
    required this.taskId,
    required this.hour,
    required this.minute,
    required this.repeatRule,
    this.weekdays,
    this.scheduledDate,
    this.advanceMinutes,
    required this.ringtone,
    required this.volume,
    required this.snoozeEnabled,
    required this.snoozeMinutes,
    required this.tier,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_id'] = Variable<int>(taskId);
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    map['repeat_rule'] = Variable<String>(repeatRule);
    if (!nullToAbsent || weekdays != null) {
      map['weekdays'] = Variable<String>(weekdays);
    }
    if (!nullToAbsent || scheduledDate != null) {
      map['scheduled_date'] = Variable<DateTime>(scheduledDate);
    }
    if (!nullToAbsent || advanceMinutes != null) {
      map['advance_minutes'] = Variable<int>(advanceMinutes);
    }
    map['ringtone'] = Variable<String>(ringtone);
    map['volume'] = Variable<int>(volume);
    map['snooze_enabled'] = Variable<bool>(snoozeEnabled);
    map['snooze_minutes'] = Variable<int>(snoozeMinutes);
    map['tier'] = Variable<String>(tier);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScheduledAlarmsCompanion toCompanion(bool nullToAbsent) {
    return ScheduledAlarmsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      hour: Value(hour),
      minute: Value(minute),
      repeatRule: Value(repeatRule),
      weekdays: weekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdays),
      scheduledDate: scheduledDate == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledDate),
      advanceMinutes: advanceMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(advanceMinutes),
      ringtone: Value(ringtone),
      volume: Value(volume),
      snoozeEnabled: Value(snoozeEnabled),
      snoozeMinutes: Value(snoozeMinutes),
      tier: Value(tier),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScheduledAlarmRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledAlarmRow(
      id: serializer.fromJson<int>(json['id']),
      taskId: serializer.fromJson<int>(json['taskId']),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
      repeatRule: serializer.fromJson<String>(json['repeatRule']),
      weekdays: serializer.fromJson<String?>(json['weekdays']),
      scheduledDate: serializer.fromJson<DateTime?>(json['scheduledDate']),
      advanceMinutes: serializer.fromJson<int?>(json['advanceMinutes']),
      ringtone: serializer.fromJson<String>(json['ringtone']),
      volume: serializer.fromJson<int>(json['volume']),
      snoozeEnabled: serializer.fromJson<bool>(json['snoozeEnabled']),
      snoozeMinutes: serializer.fromJson<int>(json['snoozeMinutes']),
      tier: serializer.fromJson<String>(json['tier']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskId': serializer.toJson<int>(taskId),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
      'repeatRule': serializer.toJson<String>(repeatRule),
      'weekdays': serializer.toJson<String?>(weekdays),
      'scheduledDate': serializer.toJson<DateTime?>(scheduledDate),
      'advanceMinutes': serializer.toJson<int?>(advanceMinutes),
      'ringtone': serializer.toJson<String>(ringtone),
      'volume': serializer.toJson<int>(volume),
      'snoozeEnabled': serializer.toJson<bool>(snoozeEnabled),
      'snoozeMinutes': serializer.toJson<int>(snoozeMinutes),
      'tier': serializer.toJson<String>(tier),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ScheduledAlarmRow copyWith({
    int? id,
    int? taskId,
    int? hour,
    int? minute,
    String? repeatRule,
    Value<String?> weekdays = const Value.absent(),
    Value<DateTime?> scheduledDate = const Value.absent(),
    Value<int?> advanceMinutes = const Value.absent(),
    String? ringtone,
    int? volume,
    bool? snoozeEnabled,
    int? snoozeMinutes,
    String? tier,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ScheduledAlarmRow(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    repeatRule: repeatRule ?? this.repeatRule,
    weekdays: weekdays.present ? weekdays.value : this.weekdays,
    scheduledDate: scheduledDate.present
        ? scheduledDate.value
        : this.scheduledDate,
    advanceMinutes: advanceMinutes.present
        ? advanceMinutes.value
        : this.advanceMinutes,
    ringtone: ringtone ?? this.ringtone,
    volume: volume ?? this.volume,
    snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    tier: tier ?? this.tier,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ScheduledAlarmRow copyWithCompanion(ScheduledAlarmsCompanion data) {
    return ScheduledAlarmRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      repeatRule: data.repeatRule.present
          ? data.repeatRule.value
          : this.repeatRule,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      scheduledDate: data.scheduledDate.present
          ? data.scheduledDate.value
          : this.scheduledDate,
      advanceMinutes: data.advanceMinutes.present
          ? data.advanceMinutes.value
          : this.advanceMinutes,
      ringtone: data.ringtone.present ? data.ringtone.value : this.ringtone,
      volume: data.volume.present ? data.volume.value : this.volume,
      snoozeEnabled: data.snoozeEnabled.present
          ? data.snoozeEnabled.value
          : this.snoozeEnabled,
      snoozeMinutes: data.snoozeMinutes.present
          ? data.snoozeMinutes.value
          : this.snoozeMinutes,
      tier: data.tier.present ? data.tier.value : this.tier,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledAlarmRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('weekdays: $weekdays, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('advanceMinutes: $advanceMinutes, ')
          ..write('ringtone: $ringtone, ')
          ..write('volume: $volume, ')
          ..write('snoozeEnabled: $snoozeEnabled, ')
          ..write('snoozeMinutes: $snoozeMinutes, ')
          ..write('tier: $tier, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    hour,
    minute,
    repeatRule,
    weekdays,
    scheduledDate,
    advanceMinutes,
    ringtone,
    volume,
    snoozeEnabled,
    snoozeMinutes,
    tier,
    enabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledAlarmRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.repeatRule == this.repeatRule &&
          other.weekdays == this.weekdays &&
          other.scheduledDate == this.scheduledDate &&
          other.advanceMinutes == this.advanceMinutes &&
          other.ringtone == this.ringtone &&
          other.volume == this.volume &&
          other.snoozeEnabled == this.snoozeEnabled &&
          other.snoozeMinutes == this.snoozeMinutes &&
          other.tier == this.tier &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScheduledAlarmsCompanion extends UpdateCompanion<ScheduledAlarmRow> {
  final Value<int> id;
  final Value<int> taskId;
  final Value<int> hour;
  final Value<int> minute;
  final Value<String> repeatRule;
  final Value<String?> weekdays;
  final Value<DateTime?> scheduledDate;
  final Value<int?> advanceMinutes;
  final Value<String> ringtone;
  final Value<int> volume;
  final Value<bool> snoozeEnabled;
  final Value<int> snoozeMinutes;
  final Value<String> tier;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ScheduledAlarmsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.scheduledDate = const Value.absent(),
    this.advanceMinutes = const Value.absent(),
    this.ringtone = const Value.absent(),
    this.volume = const Value.absent(),
    this.snoozeEnabled = const Value.absent(),
    this.snoozeMinutes = const Value.absent(),
    this.tier = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ScheduledAlarmsCompanion.insert({
    this.id = const Value.absent(),
    required int taskId,
    required int hour,
    required int minute,
    required String repeatRule,
    this.weekdays = const Value.absent(),
    this.scheduledDate = const Value.absent(),
    this.advanceMinutes = const Value.absent(),
    this.ringtone = const Value.absent(),
    this.volume = const Value.absent(),
    this.snoozeEnabled = const Value.absent(),
    this.snoozeMinutes = const Value.absent(),
    this.tier = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : taskId = Value(taskId),
       hour = Value(hour),
       minute = Value(minute),
       repeatRule = Value(repeatRule);
  static Insertable<ScheduledAlarmRow> custom({
    Expression<int>? id,
    Expression<int>? taskId,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<String>? repeatRule,
    Expression<String>? weekdays,
    Expression<DateTime>? scheduledDate,
    Expression<int>? advanceMinutes,
    Expression<String>? ringtone,
    Expression<int>? volume,
    Expression<bool>? snoozeEnabled,
    Expression<int>? snoozeMinutes,
    Expression<String>? tier,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (repeatRule != null) 'repeat_rule': repeatRule,
      if (weekdays != null) 'weekdays': weekdays,
      if (scheduledDate != null) 'scheduled_date': scheduledDate,
      if (advanceMinutes != null) 'advance_minutes': advanceMinutes,
      if (ringtone != null) 'ringtone': ringtone,
      if (volume != null) 'volume': volume,
      if (snoozeEnabled != null) 'snooze_enabled': snoozeEnabled,
      if (snoozeMinutes != null) 'snooze_minutes': snoozeMinutes,
      if (tier != null) 'tier': tier,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ScheduledAlarmsCompanion copyWith({
    Value<int>? id,
    Value<int>? taskId,
    Value<int>? hour,
    Value<int>? minute,
    Value<String>? repeatRule,
    Value<String?>? weekdays,
    Value<DateTime?>? scheduledDate,
    Value<int?>? advanceMinutes,
    Value<String>? ringtone,
    Value<int>? volume,
    Value<bool>? snoozeEnabled,
    Value<int>? snoozeMinutes,
    Value<String>? tier,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ScheduledAlarmsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatRule: repeatRule ?? this.repeatRule,
      weekdays: weekdays ?? this.weekdays,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      advanceMinutes: advanceMinutes ?? this.advanceMinutes,
      ringtone: ringtone ?? this.ringtone,
      volume: volume ?? this.volume,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      tier: tier ?? this.tier,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (repeatRule.present) {
      map['repeat_rule'] = Variable<String>(repeatRule.value);
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<String>(weekdays.value);
    }
    if (scheduledDate.present) {
      map['scheduled_date'] = Variable<DateTime>(scheduledDate.value);
    }
    if (advanceMinutes.present) {
      map['advance_minutes'] = Variable<int>(advanceMinutes.value);
    }
    if (ringtone.present) {
      map['ringtone'] = Variable<String>(ringtone.value);
    }
    if (volume.present) {
      map['volume'] = Variable<int>(volume.value);
    }
    if (snoozeEnabled.present) {
      map['snooze_enabled'] = Variable<bool>(snoozeEnabled.value);
    }
    if (snoozeMinutes.present) {
      map['snooze_minutes'] = Variable<int>(snoozeMinutes.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledAlarmsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('weekdays: $weekdays, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('advanceMinutes: $advanceMinutes, ')
          ..write('ringtone: $ringtone, ')
          ..write('volume: $volume, ')
          ..write('snoozeEnabled: $snoozeEnabled, ')
          ..write('snoozeMinutes: $snoozeMinutes, ')
          ..write('tier: $tier, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DiariesTable extends Diaries with TableInfo<$DiariesTable, Diary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _templateTypeMeta = const VerificationMeta(
    'templateType',
  );
  @override
  late final GeneratedColumn<String> templateType = GeneratedColumn<String>(
    'template_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('lined'),
  );
  static const VerificationMeta _fontSizeMeta = const VerificationMeta(
    'fontSize',
  );
  @override
  late final GeneratedColumn<double> fontSize = GeneratedColumn<double>(
    'font_size',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(16.0),
  );
  static const VerificationMeta _fontFamilyMeta = const VerificationMeta(
    'fontFamily',
  );
  @override
  late final GeneratedColumn<String> fontFamily = GeneratedColumn<String>(
    'font_family',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diaryDateMeta = const VerificationMeta(
    'diaryDate',
  );
  @override
  late final GeneratedColumn<DateTime> diaryDate = GeneratedColumn<DateTime>(
    'diary_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    templateType,
    fontSize,
    fontFamily,
    coverPath,
    diaryDate,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Diary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('template_type')) {
      context.handle(
        _templateTypeMeta,
        templateType.isAcceptableOrUnknown(
          data['template_type']!,
          _templateTypeMeta,
        ),
      );
    }
    if (data.containsKey('font_size')) {
      context.handle(
        _fontSizeMeta,
        fontSize.isAcceptableOrUnknown(data['font_size']!, _fontSizeMeta),
      );
    }
    if (data.containsKey('font_family')) {
      context.handle(
        _fontFamilyMeta,
        fontFamily.isAcceptableOrUnknown(data['font_family']!, _fontFamilyMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('diary_date')) {
      context.handle(
        _diaryDateMeta,
        diaryDate.isAcceptableOrUnknown(data['diary_date']!, _diaryDateMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Diary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Diary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      templateType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_type'],
      )!,
      fontSize: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}font_size'],
      )!,
      fontFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}font_family'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      diaryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}diary_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DiariesTable createAlias(String alias) {
    return $DiariesTable(attachedDatabase, alias);
  }
}

class Diary extends DataClass implements Insertable<Diary> {
  final int id;
  final String title;
  final String content;

  /// `lined` = 横线本 / `blank` = 空白本
  final String templateType;
  final double fontSize;

  /// null = 系统默认字体
  final String? fontFamily;

  /// 封面/图片相对路径（不存绝对路径）
  final String? coverPath;

  /// 归属日期（当天 0 点）
  final DateTime diaryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Diary({
    required this.id,
    required this.title,
    required this.content,
    required this.templateType,
    required this.fontSize,
    this.fontFamily,
    this.coverPath,
    required this.diaryDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['template_type'] = Variable<String>(templateType);
    map['font_size'] = Variable<double>(fontSize);
    if (!nullToAbsent || fontFamily != null) {
      map['font_family'] = Variable<String>(fontFamily);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['diary_date'] = Variable<DateTime>(diaryDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DiariesCompanion toCompanion(bool nullToAbsent) {
    return DiariesCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      templateType: Value(templateType),
      fontSize: Value(fontSize),
      fontFamily: fontFamily == null && nullToAbsent
          ? const Value.absent()
          : Value(fontFamily),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      diaryDate: Value(diaryDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Diary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Diary(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      templateType: serializer.fromJson<String>(json['templateType']),
      fontSize: serializer.fromJson<double>(json['fontSize']),
      fontFamily: serializer.fromJson<String?>(json['fontFamily']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      diaryDate: serializer.fromJson<DateTime>(json['diaryDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'templateType': serializer.toJson<String>(templateType),
      'fontSize': serializer.toJson<double>(fontSize),
      'fontFamily': serializer.toJson<String?>(fontFamily),
      'coverPath': serializer.toJson<String?>(coverPath),
      'diaryDate': serializer.toJson<DateTime>(diaryDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Diary copyWith({
    int? id,
    String? title,
    String? content,
    String? templateType,
    double? fontSize,
    Value<String?> fontFamily = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    DateTime? diaryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Diary(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    templateType: templateType ?? this.templateType,
    fontSize: fontSize ?? this.fontSize,
    fontFamily: fontFamily.present ? fontFamily.value : this.fontFamily,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    diaryDate: diaryDate ?? this.diaryDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Diary copyWithCompanion(DiariesCompanion data) {
    return Diary(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      templateType: data.templateType.present
          ? data.templateType.value
          : this.templateType,
      fontSize: data.fontSize.present ? data.fontSize.value : this.fontSize,
      fontFamily: data.fontFamily.present
          ? data.fontFamily.value
          : this.fontFamily,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      diaryDate: data.diaryDate.present ? data.diaryDate.value : this.diaryDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Diary(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('templateType: $templateType, ')
          ..write('fontSize: $fontSize, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('coverPath: $coverPath, ')
          ..write('diaryDate: $diaryDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    templateType,
    fontSize,
    fontFamily,
    coverPath,
    diaryDate,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Diary &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.templateType == this.templateType &&
          other.fontSize == this.fontSize &&
          other.fontFamily == this.fontFamily &&
          other.coverPath == this.coverPath &&
          other.diaryDate == this.diaryDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class DiariesCompanion extends UpdateCompanion<Diary> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> content;
  final Value<String> templateType;
  final Value<double> fontSize;
  final Value<String?> fontFamily;
  final Value<String?> coverPath;
  final Value<DateTime> diaryDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const DiariesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.templateType = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.fontFamily = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.diaryDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  DiariesCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.templateType = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.fontFamily = const Value.absent(),
    this.coverPath = const Value.absent(),
    required DateTime diaryDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
  }) : diaryDate = Value(diaryDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Diary> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? templateType,
    Expression<double>? fontSize,
    Expression<String>? fontFamily,
    Expression<String>? coverPath,
    Expression<DateTime>? diaryDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (templateType != null) 'template_type': templateType,
      if (fontSize != null) 'font_size': fontSize,
      if (fontFamily != null) 'font_family': fontFamily,
      if (coverPath != null) 'cover_path': coverPath,
      if (diaryDate != null) 'diary_date': diaryDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  DiariesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? content,
    Value<String>? templateType,
    Value<double>? fontSize,
    Value<String?>? fontFamily,
    Value<String?>? coverPath,
    Value<DateTime>? diaryDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return DiariesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      templateType: templateType ?? this.templateType,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      coverPath: coverPath ?? this.coverPath,
      diaryDate: diaryDate ?? this.diaryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (templateType.present) {
      map['template_type'] = Variable<String>(templateType.value);
    }
    if (fontSize.present) {
      map['font_size'] = Variable<double>(fontSize.value);
    }
    if (fontFamily.present) {
      map['font_family'] = Variable<String>(fontFamily.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (diaryDate.present) {
      map['diary_date'] = Variable<DateTime>(diaryDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiariesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('templateType: $templateType, ')
          ..write('fontSize: $fontSize, ')
          ..write('fontFamily: $fontFamily, ')
          ..write('coverPath: $coverPath, ')
          ..write('diaryDate: $diaryDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $MemosTable extends Memos with TableInfo<$MemosTable, Memo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    content,
    pinned,
    color,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Memo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Memo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Memo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $MemosTable createAlias(String alias) {
    return $MemosTable(attachedDatabase, alias);
  }
}

class Memo extends DataClass implements Insertable<Memo> {
  final int id;

  /// 纯文本，允许换行
  final String content;

  /// 0/1 置顶（置顶区排最前）
  final bool pinned;

  /// 可选纸色：`yellow` / `blue` / `green`（null = 默认纸色）
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 软删除
  final DateTime? deletedAt;
  const Memo({
    required this.id,
    required this.content,
    required this.pinned,
    this.color,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content'] = Variable<String>(content);
    map['pinned'] = Variable<bool>(pinned);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  MemosCompanion toCompanion(bool nullToAbsent) {
    return MemosCompanion(
      id: Value(id),
      content: Value(content),
      pinned: Value(pinned),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Memo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Memo(
      id: serializer.fromJson<int>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      color: serializer.fromJson<String?>(json['color']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content': serializer.toJson<String>(content),
      'pinned': serializer.toJson<bool>(pinned),
      'color': serializer.toJson<String?>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Memo copyWith({
    int? id,
    String? content,
    bool? pinned,
    Value<String?> color = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Memo(
    id: id ?? this.id,
    content: content ?? this.content,
    pinned: pinned ?? this.pinned,
    color: color.present ? color.value : this.color,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Memo copyWithCompanion(MemosCompanion data) {
    return Memo(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Memo(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('pinned: $pinned, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, content, pinned, color, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Memo &&
          other.id == this.id &&
          other.content == this.content &&
          other.pinned == this.pinned &&
          other.color == this.color &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class MemosCompanion extends UpdateCompanion<Memo> {
  final Value<int> id;
  final Value<String> content;
  final Value<bool> pinned;
  final Value<String?> color;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const MemosCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.pinned = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  MemosCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    this.pinned = const Value.absent(),
    this.color = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
  }) : content = Value(content),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Memo> custom({
    Expression<int>? id,
    Expression<String>? content,
    Expression<bool>? pinned,
    Expression<String>? color,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (pinned != null) 'pinned': pinned,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  MemosCompanion copyWith({
    Value<int>? id,
    Value<String>? content,
    Value<bool>? pinned,
    Value<String?>? color,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return MemosCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      pinned: pinned ?? this.pinned,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemosCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('pinned: $pinned, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $ShoppingItemsTable extends ShoppingItems
    with TableInfo<$ShoppingItemsTable, ShoppingItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedMeta = const VerificationMeta(
    'checked',
  );
  @override
  late final GeneratedColumn<bool> checked = GeneratedColumn<bool>(
    'checked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("checked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    quantity,
    category,
    checked,
    createdAt,
    checkedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShoppingItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('checked')) {
      context.handle(
        _checkedMeta,
        checked.isAcceptableOrUnknown(data['checked']!, _checkedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      checked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}checked'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ShoppingItemsTable createAlias(String alias) {
    return $ShoppingItemsTable(attachedDatabase, alias);
  }
}

class ShoppingItem extends DataClass implements Insertable<ShoppingItem> {
  final int id;

  /// 商品名（用户输入，原样保存；空白输入不落库）
  final String name;

  /// 数量，默认 1（V1 不在 UI 暴露编辑，字段先留住）
  final int quantity;

  /// 分类（可空）；空 → UI 归到「其他」
  final String? category;

  /// 是否已购
  final bool checked;
  final DateTime createdAt;

  /// 勾选时间（取消勾选时置空；用于「本次清单」的先后顺序）
  final DateTime? checkedAt;

  /// 软删除
  final DateTime? deletedAt;
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.category,
    required this.checked,
    required this.createdAt,
    this.checkedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['checked'] = Variable<bool>(checked);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || checkedAt != null) {
      map['checked_at'] = Variable<DateTime>(checkedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ShoppingItemsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingItemsCompanion(
      id: Value(id),
      name: Value(name),
      quantity: Value(quantity),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      checked: Value(checked),
      createdAt: Value(createdAt),
      checkedAt: checkedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(checkedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ShoppingItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingItem(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<int>(json['quantity']),
      category: serializer.fromJson<String?>(json['category']),
      checked: serializer.fromJson<bool>(json['checked']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      checkedAt: serializer.fromJson<DateTime?>(json['checkedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<int>(quantity),
      'category': serializer.toJson<String?>(category),
      'checked': serializer.toJson<bool>(checked),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'checkedAt': serializer.toJson<DateTime?>(checkedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ShoppingItem copyWith({
    int? id,
    String? name,
    int? quantity,
    Value<String?> category = const Value.absent(),
    bool? checked,
    DateTime? createdAt,
    Value<DateTime?> checkedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ShoppingItem(
    id: id ?? this.id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    category: category.present ? category.value : this.category,
    checked: checked ?? this.checked,
    createdAt: createdAt ?? this.createdAt,
    checkedAt: checkedAt.present ? checkedAt.value : this.checkedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ShoppingItem copyWithCompanion(ShoppingItemsCompanion data) {
    return ShoppingItem(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      category: data.category.present ? data.category.value : this.category,
      checked: data.checked.present ? data.checked.value : this.checked,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItem(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('category: $category, ')
          ..write('checked: $checked, ')
          ..write('createdAt: $createdAt, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    quantity,
    category,
    checked,
    createdAt,
    checkedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingItem &&
          other.id == this.id &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.category == this.category &&
          other.checked == this.checked &&
          other.createdAt == this.createdAt &&
          other.checkedAt == this.checkedAt &&
          other.deletedAt == this.deletedAt);
}

class ShoppingItemsCompanion extends UpdateCompanion<ShoppingItem> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> quantity;
  final Value<String?> category;
  final Value<bool> checked;
  final Value<DateTime> createdAt;
  final Value<DateTime?> checkedAt;
  final Value<DateTime?> deletedAt;
  const ShoppingItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.category = const Value.absent(),
    this.checked = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  ShoppingItemsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.quantity = const Value.absent(),
    this.category = const Value.absent(),
    this.checked = const Value.absent(),
    required DateTime createdAt,
    this.checkedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ShoppingItem> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? quantity,
    Expression<String>? category,
    Expression<bool>? checked,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? checkedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (category != null) 'category': category,
      if (checked != null) 'checked': checked,
      if (createdAt != null) 'created_at': createdAt,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  ShoppingItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? quantity,
    Value<String?>? category,
    Value<bool>? checked,
    Value<DateTime>? createdAt,
    Value<DateTime?>? checkedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return ShoppingItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      checked: checked ?? this.checked,
      createdAt: createdAt ?? this.createdAt,
      checkedAt: checkedAt ?? this.checkedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (checked.present) {
      map['checked'] = Variable<bool>(checked.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('category: $category, ')
          ..write('checked: $checked, ')
          ..write('createdAt: $createdAt, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $BirthdaysTable extends Birthdays
    with TableInfo<$BirthdaysTable, Birthday> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BirthdaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _birthdayYearMeta = const VerificationMeta(
    'birthdayYear',
  );
  @override
  late final GeneratedColumn<int> birthdayYear = GeneratedColumn<int>(
    'birthday_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthdayMonthMeta = const VerificationMeta(
    'birthdayMonth',
  );
  @override
  late final GeneratedColumn<int> birthdayMonth = GeneratedColumn<int>(
    'birthday_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _birthdayDayMeta = const VerificationMeta(
    'birthdayDay',
  );
  @override
  late final GeneratedColumn<int> birthdayDay = GeneratedColumn<int>(
    'birthday_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calendarTypeMeta = const VerificationMeta(
    'calendarType',
  );
  @override
  late final GeneratedColumn<String> calendarType = GeneratedColumn<String>(
    'calendar_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('solar'),
  );
  static const VerificationMeta _groupTagMeta = const VerificationMeta(
    'groupTag',
  );
  @override
  late final GeneratedColumn<String> groupTag = GeneratedColumn<String>(
    'group_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _advanceDaysMeta = const VerificationMeta(
    'advanceDays',
  );
  @override
  late final GeneratedColumn<int> advanceDays = GeneratedColumn<int>(
    'advance_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    birthdayYear,
    birthdayMonth,
    birthdayDay,
    calendarType,
    groupTag,
    advanceDays,
    notes,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'birthdays';
  @override
  VerificationContext validateIntegrity(
    Insertable<Birthday> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('birthday_year')) {
      context.handle(
        _birthdayYearMeta,
        birthdayYear.isAcceptableOrUnknown(
          data['birthday_year']!,
          _birthdayYearMeta,
        ),
      );
    }
    if (data.containsKey('birthday_month')) {
      context.handle(
        _birthdayMonthMeta,
        birthdayMonth.isAcceptableOrUnknown(
          data['birthday_month']!,
          _birthdayMonthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_birthdayMonthMeta);
    }
    if (data.containsKey('birthday_day')) {
      context.handle(
        _birthdayDayMeta,
        birthdayDay.isAcceptableOrUnknown(
          data['birthday_day']!,
          _birthdayDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_birthdayDayMeta);
    }
    if (data.containsKey('calendar_type')) {
      context.handle(
        _calendarTypeMeta,
        calendarType.isAcceptableOrUnknown(
          data['calendar_type']!,
          _calendarTypeMeta,
        ),
      );
    }
    if (data.containsKey('group_tag')) {
      context.handle(
        _groupTagMeta,
        groupTag.isAcceptableOrUnknown(data['group_tag']!, _groupTagMeta),
      );
    }
    if (data.containsKey('advance_days')) {
      context.handle(
        _advanceDaysMeta,
        advanceDays.isAcceptableOrUnknown(
          data['advance_days']!,
          _advanceDaysMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Birthday map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Birthday(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      birthdayYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birthday_year'],
      ),
      birthdayMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birthday_month'],
      )!,
      birthdayDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birthday_day'],
      )!,
      calendarType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calendar_type'],
      )!,
      groupTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_tag'],
      ),
      advanceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}advance_days'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $BirthdaysTable createAlias(String alias) {
    return $BirthdaysTable(attachedDatabase, alias);
  }
}

class Birthday extends DataClass implements Insertable<Birthday> {
  final int id;
  final String name;

  /// 出生年（可空：很多人只记得月日）
  final int? birthdayYear;

  /// 农历时是农历月（1–12，不含闰月标记）
  final int birthdayMonth;

  /// 农历时是农历日（1–30）
  final int birthdayDay;

  /// `solar` | `lunar`
  final String calendarType;

  /// 分组标签（可空）：家人 / 朋友 / 同事…
  final String? groupTag;

  /// 提前几天提醒（0 = 当天）
  final int advanceDays;
  final String? notes;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const Birthday({
    required this.id,
    required this.name,
    this.birthdayYear,
    required this.birthdayMonth,
    required this.birthdayDay,
    required this.calendarType,
    this.groupTag,
    required this.advanceDays,
    this.notes,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || birthdayYear != null) {
      map['birthday_year'] = Variable<int>(birthdayYear);
    }
    map['birthday_month'] = Variable<int>(birthdayMonth);
    map['birthday_day'] = Variable<int>(birthdayDay);
    map['calendar_type'] = Variable<String>(calendarType);
    if (!nullToAbsent || groupTag != null) {
      map['group_tag'] = Variable<String>(groupTag);
    }
    map['advance_days'] = Variable<int>(advanceDays);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  BirthdaysCompanion toCompanion(bool nullToAbsent) {
    return BirthdaysCompanion(
      id: Value(id),
      name: Value(name),
      birthdayYear: birthdayYear == null && nullToAbsent
          ? const Value.absent()
          : Value(birthdayYear),
      birthdayMonth: Value(birthdayMonth),
      birthdayDay: Value(birthdayDay),
      calendarType: Value(calendarType),
      groupTag: groupTag == null && nullToAbsent
          ? const Value.absent()
          : Value(groupTag),
      advanceDays: Value(advanceDays),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Birthday.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Birthday(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      birthdayYear: serializer.fromJson<int?>(json['birthdayYear']),
      birthdayMonth: serializer.fromJson<int>(json['birthdayMonth']),
      birthdayDay: serializer.fromJson<int>(json['birthdayDay']),
      calendarType: serializer.fromJson<String>(json['calendarType']),
      groupTag: serializer.fromJson<String?>(json['groupTag']),
      advanceDays: serializer.fromJson<int>(json['advanceDays']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'birthdayYear': serializer.toJson<int?>(birthdayYear),
      'birthdayMonth': serializer.toJson<int>(birthdayMonth),
      'birthdayDay': serializer.toJson<int>(birthdayDay),
      'calendarType': serializer.toJson<String>(calendarType),
      'groupTag': serializer.toJson<String?>(groupTag),
      'advanceDays': serializer.toJson<int>(advanceDays),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Birthday copyWith({
    int? id,
    String? name,
    Value<int?> birthdayYear = const Value.absent(),
    int? birthdayMonth,
    int? birthdayDay,
    String? calendarType,
    Value<String?> groupTag = const Value.absent(),
    int? advanceDays,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Birthday(
    id: id ?? this.id,
    name: name ?? this.name,
    birthdayYear: birthdayYear.present ? birthdayYear.value : this.birthdayYear,
    birthdayMonth: birthdayMonth ?? this.birthdayMonth,
    birthdayDay: birthdayDay ?? this.birthdayDay,
    calendarType: calendarType ?? this.calendarType,
    groupTag: groupTag.present ? groupTag.value : this.groupTag,
    advanceDays: advanceDays ?? this.advanceDays,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Birthday copyWithCompanion(BirthdaysCompanion data) {
    return Birthday(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      birthdayYear: data.birthdayYear.present
          ? data.birthdayYear.value
          : this.birthdayYear,
      birthdayMonth: data.birthdayMonth.present
          ? data.birthdayMonth.value
          : this.birthdayMonth,
      birthdayDay: data.birthdayDay.present
          ? data.birthdayDay.value
          : this.birthdayDay,
      calendarType: data.calendarType.present
          ? data.calendarType.value
          : this.calendarType,
      groupTag: data.groupTag.present ? data.groupTag.value : this.groupTag,
      advanceDays: data.advanceDays.present
          ? data.advanceDays.value
          : this.advanceDays,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Birthday(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('birthdayYear: $birthdayYear, ')
          ..write('birthdayMonth: $birthdayMonth, ')
          ..write('birthdayDay: $birthdayDay, ')
          ..write('calendarType: $calendarType, ')
          ..write('groupTag: $groupTag, ')
          ..write('advanceDays: $advanceDays, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    birthdayYear,
    birthdayMonth,
    birthdayDay,
    calendarType,
    groupTag,
    advanceDays,
    notes,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Birthday &&
          other.id == this.id &&
          other.name == this.name &&
          other.birthdayYear == this.birthdayYear &&
          other.birthdayMonth == this.birthdayMonth &&
          other.birthdayDay == this.birthdayDay &&
          other.calendarType == this.calendarType &&
          other.groupTag == this.groupTag &&
          other.advanceDays == this.advanceDays &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class BirthdaysCompanion extends UpdateCompanion<Birthday> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> birthdayYear;
  final Value<int> birthdayMonth;
  final Value<int> birthdayDay;
  final Value<String> calendarType;
  final Value<String?> groupTag;
  final Value<int> advanceDays;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  const BirthdaysCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.birthdayYear = const Value.absent(),
    this.birthdayMonth = const Value.absent(),
    this.birthdayDay = const Value.absent(),
    this.calendarType = const Value.absent(),
    this.groupTag = const Value.absent(),
    this.advanceDays = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  BirthdaysCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.birthdayYear = const Value.absent(),
    required int birthdayMonth,
    required int birthdayDay,
    this.calendarType = const Value.absent(),
    this.groupTag = const Value.absent(),
    this.advanceDays = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    this.deletedAt = const Value.absent(),
  }) : name = Value(name),
       birthdayMonth = Value(birthdayMonth),
       birthdayDay = Value(birthdayDay),
       createdAt = Value(createdAt);
  static Insertable<Birthday> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? birthdayYear,
    Expression<int>? birthdayMonth,
    Expression<int>? birthdayDay,
    Expression<String>? calendarType,
    Expression<String>? groupTag,
    Expression<int>? advanceDays,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (birthdayYear != null) 'birthday_year': birthdayYear,
      if (birthdayMonth != null) 'birthday_month': birthdayMonth,
      if (birthdayDay != null) 'birthday_day': birthdayDay,
      if (calendarType != null) 'calendar_type': calendarType,
      if (groupTag != null) 'group_tag': groupTag,
      if (advanceDays != null) 'advance_days': advanceDays,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  BirthdaysCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? birthdayYear,
    Value<int>? birthdayMonth,
    Value<int>? birthdayDay,
    Value<String>? calendarType,
    Value<String?>? groupTag,
    Value<int>? advanceDays,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
  }) {
    return BirthdaysCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      birthdayYear: birthdayYear ?? this.birthdayYear,
      birthdayMonth: birthdayMonth ?? this.birthdayMonth,
      birthdayDay: birthdayDay ?? this.birthdayDay,
      calendarType: calendarType ?? this.calendarType,
      groupTag: groupTag ?? this.groupTag,
      advanceDays: advanceDays ?? this.advanceDays,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (birthdayYear.present) {
      map['birthday_year'] = Variable<int>(birthdayYear.value);
    }
    if (birthdayMonth.present) {
      map['birthday_month'] = Variable<int>(birthdayMonth.value);
    }
    if (birthdayDay.present) {
      map['birthday_day'] = Variable<int>(birthdayDay.value);
    }
    if (calendarType.present) {
      map['calendar_type'] = Variable<String>(calendarType.value);
    }
    if (groupTag.present) {
      map['group_tag'] = Variable<String>(groupTag.value);
    }
    if (advanceDays.present) {
      map['advance_days'] = Variable<int>(advanceDays.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BirthdaysCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('birthdayYear: $birthdayYear, ')
          ..write('birthdayMonth: $birthdayMonth, ')
          ..write('birthdayDay: $birthdayDay, ')
          ..write('calendarType: $calendarType, ')
          ..write('groupTag: $groupTag, ')
          ..write('advanceDays: $advanceDays, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $CalorieEntriesTable extends CalorieEntries
    with TableInfo<$CalorieEntriesTable, CalorieEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalorieEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entryDateMeta = const VerificationMeta(
    'entryDate',
  );
  @override
  late final GeneratedColumn<DateTime> entryDate = GeneratedColumn<DateTime>(
    'entry_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealMeta = const VerificationMeta('meal');
  @override
  late final GeneratedColumn<String> meal = GeneratedColumn<String>(
    'meal',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<int> kcal = GeneratedColumn<int>(
    'kcal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinGMeta = const VerificationMeta(
    'proteinG',
  );
  @override
  late final GeneratedColumn<double> proteinG = GeneratedColumn<double>(
    'protein_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _carbGMeta = const VerificationMeta('carbG');
  @override
  late final GeneratedColumn<double> carbG = GeneratedColumn<double>(
    'carb_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
    'fat_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entryDate,
    meal,
    name,
    kcal,
    proteinG,
    carbG,
    fatG,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calorie_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalorieEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entry_date')) {
      context.handle(
        _entryDateMeta,
        entryDate.isAcceptableOrUnknown(data['entry_date']!, _entryDateMeta),
      );
    } else if (isInserting) {
      context.missing(_entryDateMeta);
    }
    if (data.containsKey('meal')) {
      context.handle(
        _mealMeta,
        meal.isAcceptableOrUnknown(data['meal']!, _mealMeta),
      );
    } else if (isInserting) {
      context.missing(_mealMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    } else if (isInserting) {
      context.missing(_kcalMeta);
    }
    if (data.containsKey('protein_g')) {
      context.handle(
        _proteinGMeta,
        proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta),
      );
    }
    if (data.containsKey('carb_g')) {
      context.handle(
        _carbGMeta,
        carbG.isAcceptableOrUnknown(data['carb_g']!, _carbGMeta),
      );
    }
    if (data.containsKey('fat_g')) {
      context.handle(
        _fatGMeta,
        fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalorieEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalorieEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}entry_date'],
      )!,
      meal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kcal'],
      )!,
      proteinG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_g'],
      )!,
      carbG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carb_g'],
      )!,
      fatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_g'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CalorieEntriesTable createAlias(String alias) {
    return $CalorieEntriesTable(attachedDatabase, alias);
  }
}

class CalorieEntry extends DataClass implements Insertable<CalorieEntry> {
  final int id;

  /// 归属日（当天 0 点，与任务/日记一致：按本地日期比较）
  final DateTime entryDate;

  /// `breakfast` / `lunch` / `dinner` / `snack`
  final String meal;

  /// 食物名（用户原文，用于历史联想）
  final String name;
  final int kcal;
  final double proteinG;
  final double carbG;
  final double fatG;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const CalorieEntry({
    required this.id,
    required this.entryDate,
    required this.meal,
    required this.name,
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entry_date'] = Variable<DateTime>(entryDate);
    map['meal'] = Variable<String>(meal);
    map['name'] = Variable<String>(name);
    map['kcal'] = Variable<int>(kcal);
    map['protein_g'] = Variable<double>(proteinG);
    map['carb_g'] = Variable<double>(carbG);
    map['fat_g'] = Variable<double>(fatG);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CalorieEntriesCompanion toCompanion(bool nullToAbsent) {
    return CalorieEntriesCompanion(
      id: Value(id),
      entryDate: Value(entryDate),
      meal: Value(meal),
      name: Value(name),
      kcal: Value(kcal),
      proteinG: Value(proteinG),
      carbG: Value(carbG),
      fatG: Value(fatG),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CalorieEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalorieEntry(
      id: serializer.fromJson<int>(json['id']),
      entryDate: serializer.fromJson<DateTime>(json['entryDate']),
      meal: serializer.fromJson<String>(json['meal']),
      name: serializer.fromJson<String>(json['name']),
      kcal: serializer.fromJson<int>(json['kcal']),
      proteinG: serializer.fromJson<double>(json['proteinG']),
      carbG: serializer.fromJson<double>(json['carbG']),
      fatG: serializer.fromJson<double>(json['fatG']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entryDate': serializer.toJson<DateTime>(entryDate),
      'meal': serializer.toJson<String>(meal),
      'name': serializer.toJson<String>(name),
      'kcal': serializer.toJson<int>(kcal),
      'proteinG': serializer.toJson<double>(proteinG),
      'carbG': serializer.toJson<double>(carbG),
      'fatG': serializer.toJson<double>(fatG),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CalorieEntry copyWith({
    int? id,
    DateTime? entryDate,
    String? meal,
    String? name,
    int? kcal,
    double? proteinG,
    double? carbG,
    double? fatG,
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => CalorieEntry(
    id: id ?? this.id,
    entryDate: entryDate ?? this.entryDate,
    meal: meal ?? this.meal,
    name: name ?? this.name,
    kcal: kcal ?? this.kcal,
    proteinG: proteinG ?? this.proteinG,
    carbG: carbG ?? this.carbG,
    fatG: fatG ?? this.fatG,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CalorieEntry copyWithCompanion(CalorieEntriesCompanion data) {
    return CalorieEntry(
      id: data.id.present ? data.id.value : this.id,
      entryDate: data.entryDate.present ? data.entryDate.value : this.entryDate,
      meal: data.meal.present ? data.meal.value : this.meal,
      name: data.name.present ? data.name.value : this.name,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      carbG: data.carbG.present ? data.carbG.value : this.carbG,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalorieEntry(')
          ..write('id: $id, ')
          ..write('entryDate: $entryDate, ')
          ..write('meal: $meal, ')
          ..write('name: $name, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbG: $carbG, ')
          ..write('fatG: $fatG, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entryDate,
    meal,
    name,
    kcal,
    proteinG,
    carbG,
    fatG,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalorieEntry &&
          other.id == this.id &&
          other.entryDate == this.entryDate &&
          other.meal == this.meal &&
          other.name == this.name &&
          other.kcal == this.kcal &&
          other.proteinG == this.proteinG &&
          other.carbG == this.carbG &&
          other.fatG == this.fatG &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class CalorieEntriesCompanion extends UpdateCompanion<CalorieEntry> {
  final Value<int> id;
  final Value<DateTime> entryDate;
  final Value<String> meal;
  final Value<String> name;
  final Value<int> kcal;
  final Value<double> proteinG;
  final Value<double> carbG;
  final Value<double> fatG;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  const CalorieEntriesCompanion({
    this.id = const Value.absent(),
    this.entryDate = const Value.absent(),
    this.meal = const Value.absent(),
    this.name = const Value.absent(),
    this.kcal = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.carbG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  CalorieEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime entryDate,
    required String meal,
    required String name,
    required int kcal,
    this.proteinG = const Value.absent(),
    this.carbG = const Value.absent(),
    this.fatG = const Value.absent(),
    required DateTime createdAt,
    this.deletedAt = const Value.absent(),
  }) : entryDate = Value(entryDate),
       meal = Value(meal),
       name = Value(name),
       kcal = Value(kcal),
       createdAt = Value(createdAt);
  static Insertable<CalorieEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? entryDate,
    Expression<String>? meal,
    Expression<String>? name,
    Expression<int>? kcal,
    Expression<double>? proteinG,
    Expression<double>? carbG,
    Expression<double>? fatG,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryDate != null) 'entry_date': entryDate,
      if (meal != null) 'meal': meal,
      if (name != null) 'name': name,
      if (kcal != null) 'kcal': kcal,
      if (proteinG != null) 'protein_g': proteinG,
      if (carbG != null) 'carb_g': carbG,
      if (fatG != null) 'fat_g': fatG,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  CalorieEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? entryDate,
    Value<String>? meal,
    Value<String>? name,
    Value<int>? kcal,
    Value<double>? proteinG,
    Value<double>? carbG,
    Value<double>? fatG,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
  }) {
    return CalorieEntriesCompanion(
      id: id ?? this.id,
      entryDate: entryDate ?? this.entryDate,
      meal: meal ?? this.meal,
      name: name ?? this.name,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      carbG: carbG ?? this.carbG,
      fatG: fatG ?? this.fatG,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entryDate.present) {
      map['entry_date'] = Variable<DateTime>(entryDate.value);
    }
    if (meal.present) {
      map['meal'] = Variable<String>(meal.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<int>(kcal.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<double>(proteinG.value);
    }
    if (carbG.present) {
      map['carb_g'] = Variable<double>(carbG.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalorieEntriesCompanion(')
          ..write('id: $id, ')
          ..write('entryDate: $entryDate, ')
          ..write('meal: $meal, ')
          ..write('name: $name, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('carbG: $carbG, ')
          ..write('fatG: $fatG, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $LocationRemindersTable extends LocationReminders
    with TableInfo<$LocationRemindersTable, LocationReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placeNameMeta = const VerificationMeta(
    'placeName',
  );
  @override
  late final GeneratedColumn<String> placeName = GeneratedColumn<String>(
    'place_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _radiusMetersMeta = const VerificationMeta(
    'radiusMeters',
  );
  @override
  late final GeneratedColumn<int> radiusMeters = GeneratedColumn<int>(
    'radius_meters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(200),
  );
  static const VerificationMeta _triggerOnMeta = const VerificationMeta(
    'triggerOn',
  );
  @override
  late final GeneratedColumn<String> triggerOn = GeneratedColumn<String>(
    'trigger_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('enter'),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notifiedAtMeta = const VerificationMeta(
    'notifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> notifiedAt = GeneratedColumn<DateTime>(
    'notified_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    placeName,
    latitude,
    longitude,
    radiusMeters,
    triggerOn,
    enabled,
    notifiedAt,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('place_name')) {
      context.handle(
        _placeNameMeta,
        placeName.isAcceptableOrUnknown(data['place_name']!, _placeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_placeNameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('radius_meters')) {
      context.handle(
        _radiusMetersMeta,
        radiusMeters.isAcceptableOrUnknown(
          data['radius_meters']!,
          _radiusMetersMeta,
        ),
      );
    }
    if (data.containsKey('trigger_on')) {
      context.handle(
        _triggerOnMeta,
        triggerOn.isAcceptableOrUnknown(data['trigger_on']!, _triggerOnMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('notified_at')) {
      context.handle(
        _notifiedAtMeta,
        notifiedAt.isAcceptableOrUnknown(data['notified_at']!, _notifiedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      placeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      radiusMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}radius_meters'],
      )!,
      triggerOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_on'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      notifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}notified_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $LocationRemindersTable createAlias(String alias) {
    return $LocationRemindersTable(attachedDatabase, alias);
  }
}

class LocationReminder extends DataClass
    implements Insertable<LocationReminder> {
  final int id;

  /// 提醒文案（通知标题）
  final String title;

  /// 地点名（用户看得懂的名字，不反查地理编码）
  final String placeName;
  final double latitude;
  final double longitude;

  /// 触发半径（米），默认 200
  final int radiusMeters;

  /// `enter`（进入）/ `exit`（离开）
  final String triggerOn;
  final bool enabled;

  /// 上次触发时间（24 小时内不重复提醒）
  final DateTime? notifiedAt;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const LocationReminder({
    required this.id,
    required this.title,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.triggerOn,
    required this.enabled,
    this.notifiedAt,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['place_name'] = Variable<String>(placeName);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['radius_meters'] = Variable<int>(radiusMeters);
    map['trigger_on'] = Variable<String>(triggerOn);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || notifiedAt != null) {
      map['notified_at'] = Variable<DateTime>(notifiedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocationRemindersCompanion toCompanion(bool nullToAbsent) {
    return LocationRemindersCompanion(
      id: Value(id),
      title: Value(title),
      placeName: Value(placeName),
      latitude: Value(latitude),
      longitude: Value(longitude),
      radiusMeters: Value(radiusMeters),
      triggerOn: Value(triggerOn),
      enabled: Value(enabled),
      notifiedAt: notifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(notifiedAt),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocationReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationReminder(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      placeName: serializer.fromJson<String>(json['placeName']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      radiusMeters: serializer.fromJson<int>(json['radiusMeters']),
      triggerOn: serializer.fromJson<String>(json['triggerOn']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      notifiedAt: serializer.fromJson<DateTime?>(json['notifiedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'placeName': serializer.toJson<String>(placeName),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'radiusMeters': serializer.toJson<int>(radiusMeters),
      'triggerOn': serializer.toJson<String>(triggerOn),
      'enabled': serializer.toJson<bool>(enabled),
      'notifiedAt': serializer.toJson<DateTime?>(notifiedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocationReminder copyWith({
    int? id,
    String? title,
    String? placeName,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    String? triggerOn,
    bool? enabled,
    Value<DateTime?> notifiedAt = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => LocationReminder(
    id: id ?? this.id,
    title: title ?? this.title,
    placeName: placeName ?? this.placeName,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    triggerOn: triggerOn ?? this.triggerOn,
    enabled: enabled ?? this.enabled,
    notifiedAt: notifiedAt.present ? notifiedAt.value : this.notifiedAt,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  LocationReminder copyWithCompanion(LocationRemindersCompanion data) {
    return LocationReminder(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      placeName: data.placeName.present ? data.placeName.value : this.placeName,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      radiusMeters: data.radiusMeters.present
          ? data.radiusMeters.value
          : this.radiusMeters,
      triggerOn: data.triggerOn.present ? data.triggerOn.value : this.triggerOn,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      notifiedAt: data.notifiedAt.present
          ? data.notifiedAt.value
          : this.notifiedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationReminder(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('placeName: $placeName, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('triggerOn: $triggerOn, ')
          ..write('enabled: $enabled, ')
          ..write('notifiedAt: $notifiedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    placeName,
    latitude,
    longitude,
    radiusMeters,
    triggerOn,
    enabled,
    notifiedAt,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationReminder &&
          other.id == this.id &&
          other.title == this.title &&
          other.placeName == this.placeName &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.radiusMeters == this.radiusMeters &&
          other.triggerOn == this.triggerOn &&
          other.enabled == this.enabled &&
          other.notifiedAt == this.notifiedAt &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class LocationRemindersCompanion extends UpdateCompanion<LocationReminder> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> placeName;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<int> radiusMeters;
  final Value<String> triggerOn;
  final Value<bool> enabled;
  final Value<DateTime?> notifiedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  const LocationRemindersCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.placeName = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radiusMeters = const Value.absent(),
    this.triggerOn = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notifiedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  LocationRemindersCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String placeName,
    required double latitude,
    required double longitude,
    this.radiusMeters = const Value.absent(),
    this.triggerOn = const Value.absent(),
    this.enabled = const Value.absent(),
    this.notifiedAt = const Value.absent(),
    required DateTime createdAt,
    this.deletedAt = const Value.absent(),
  }) : title = Value(title),
       placeName = Value(placeName),
       latitude = Value(latitude),
       longitude = Value(longitude),
       createdAt = Value(createdAt);
  static Insertable<LocationReminder> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? placeName,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? radiusMeters,
    Expression<String>? triggerOn,
    Expression<bool>? enabled,
    Expression<DateTime>? notifiedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (placeName != null) 'place_name': placeName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (triggerOn != null) 'trigger_on': triggerOn,
      if (enabled != null) 'enabled': enabled,
      if (notifiedAt != null) 'notified_at': notifiedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  LocationRemindersCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? placeName,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<int>? radiusMeters,
    Value<String>? triggerOn,
    Value<bool>? enabled,
    Value<DateTime?>? notifiedAt,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
  }) {
    return LocationRemindersCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      placeName: placeName ?? this.placeName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      triggerOn: triggerOn ?? this.triggerOn,
      enabled: enabled ?? this.enabled,
      notifiedAt: notifiedAt ?? this.notifiedAt,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (placeName.present) {
      map['place_name'] = Variable<String>(placeName.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (radiusMeters.present) {
      map['radius_meters'] = Variable<int>(radiusMeters.value);
    }
    if (triggerOn.present) {
      map['trigger_on'] = Variable<String>(triggerOn.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (notifiedAt.present) {
      map['notified_at'] = Variable<DateTime>(notifiedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationRemindersCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('placeName: $placeName, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('triggerOn: $triggerOn, ')
          ..write('enabled: $enabled, ')
          ..write('notifiedAt: $notifiedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TaskTemplatesTable taskTemplates = $TaskTemplatesTable(this);
  late final $TaskInstancesTable taskInstances = $TaskInstancesTable(this);
  late final $ScheduledAlarmsTable scheduledAlarms = $ScheduledAlarmsTable(
    this,
  );
  late final $DiariesTable diaries = $DiariesTable(this);
  late final $MemosTable memos = $MemosTable(this);
  late final $ShoppingItemsTable shoppingItems = $ShoppingItemsTable(this);
  late final $BirthdaysTable birthdays = $BirthdaysTable(this);
  late final $CalorieEntriesTable calorieEntries = $CalorieEntriesTable(this);
  late final $LocationRemindersTable locationReminders =
      $LocationRemindersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    taskTemplates,
    taskInstances,
    scheduledAlarms,
    diaries,
    memos,
    shoppingItems,
    birthdays,
    calorieEntries,
    locationReminders,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'task_templates',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scheduled_alarms', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TaskTemplatesTableCreateCompanionBuilder =
    TaskTemplatesCompanion Function({
      Value<int> id,
      required String type,
      required String title,
      required String repeatMode,
      Value<String?> repeatDays,
      required DateTime startDate,
      Value<DateTime?> endDate,
      Value<int?> reminderMinutesBefore,
      Value<bool> alarmEnabled,
      Value<String?> alarmConfigJson,
      Value<double?> caloriePerMinute,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
    });
typedef $$TaskTemplatesTableUpdateCompanionBuilder =
    TaskTemplatesCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<String> title,
      Value<String> repeatMode,
      Value<String?> repeatDays,
      Value<DateTime> startDate,
      Value<DateTime?> endDate,
      Value<int?> reminderMinutesBefore,
      Value<bool> alarmEnabled,
      Value<String?> alarmConfigJson,
      Value<double?> caloriePerMinute,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
    });

final class $$TaskTemplatesTableReferences
    extends
        BaseReferences<_$AppDatabase, $TaskTemplatesTable, TaskTemplateRow> {
  $$TaskTemplatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TaskInstancesTable, List<TaskInstanceRow>>
  _taskInstancesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskInstances,
    aliasName: 'task_templates__id__task_instances__template_id',
  );

  $$TaskInstancesTableProcessedTableManager get taskInstancesRefs {
    final manager = $$TaskInstancesTableTableManager(
      $_db,
      $_db.taskInstances,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskInstancesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScheduledAlarmsTable, List<ScheduledAlarmRow>>
  _scheduledAlarmsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.scheduledAlarms,
    aliasName: 'task_templates__id__scheduled_alarms__task_id',
  );

  $$ScheduledAlarmsTableProcessedTableManager get scheduledAlarmsRefs {
    final manager = $$ScheduledAlarmsTableTableManager(
      $_db,
      $_db.scheduledAlarms,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledAlarmsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TaskTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTemplatesTable> {
  $$TaskTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatDays => $composableBuilder(
    column: $table.repeatDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alarmConfigJson => $composableBuilder(
    column: $table.alarmConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get caloriePerMinute => $composableBuilder(
    column: $table.caloriePerMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskInstancesRefs(
    Expression<bool> Function($$TaskInstancesTableFilterComposer f) f,
  ) {
    final $$TaskInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskInstances,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskInstancesTableFilterComposer(
            $db: $db,
            $table: $db.taskInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scheduledAlarmsRefs(
    Expression<bool> Function($$ScheduledAlarmsTableFilterComposer f) f,
  ) {
    final $$ScheduledAlarmsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduledAlarms,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduledAlarmsTableFilterComposer(
            $db: $db,
            $table: $db.scheduledAlarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTemplatesTable> {
  $$TaskTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatDays => $composableBuilder(
    column: $table.repeatDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alarmConfigJson => $composableBuilder(
    column: $table.alarmConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get caloriePerMinute => $composableBuilder(
    column: $table.caloriePerMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTemplatesTable> {
  $$TaskTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get repeatMode => $composableBuilder(
    column: $table.repeatMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repeatDays => $composableBuilder(
    column: $table.repeatDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alarmConfigJson => $composableBuilder(
    column: $table.alarmConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get caloriePerMinute => $composableBuilder(
    column: $table.caloriePerMinute,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> taskInstancesRefs<T extends Object>(
    Expression<T> Function($$TaskInstancesTableAnnotationComposer a) f,
  ) {
    final $$TaskInstancesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskInstances,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskInstancesTableAnnotationComposer(
            $db: $db,
            $table: $db.taskInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scheduledAlarmsRefs<T extends Object>(
    Expression<T> Function($$ScheduledAlarmsTableAnnotationComposer a) f,
  ) {
    final $$ScheduledAlarmsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scheduledAlarms,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduledAlarmsTableAnnotationComposer(
            $db: $db,
            $table: $db.scheduledAlarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskTemplatesTable,
          TaskTemplateRow,
          $$TaskTemplatesTableFilterComposer,
          $$TaskTemplatesTableOrderingComposer,
          $$TaskTemplatesTableAnnotationComposer,
          $$TaskTemplatesTableCreateCompanionBuilder,
          $$TaskTemplatesTableUpdateCompanionBuilder,
          (TaskTemplateRow, $$TaskTemplatesTableReferences),
          TaskTemplateRow,
          PrefetchHooks Function({
            bool taskInstancesRefs,
            bool scheduledAlarmsRefs,
          })
        > {
  $$TaskTemplatesTableTableManager(_$AppDatabase db, $TaskTemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> repeatMode = const Value.absent(),
                Value<String?> repeatDays = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<int?> reminderMinutesBefore = const Value.absent(),
                Value<bool> alarmEnabled = const Value.absent(),
                Value<String?> alarmConfigJson = const Value.absent(),
                Value<double?> caloriePerMinute = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TaskTemplatesCompanion(
                id: id,
                type: type,
                title: title,
                repeatMode: repeatMode,
                repeatDays: repeatDays,
                startDate: startDate,
                endDate: endDate,
                reminderMinutesBefore: reminderMinutesBefore,
                alarmEnabled: alarmEnabled,
                alarmConfigJson: alarmConfigJson,
                caloriePerMinute: caloriePerMinute,
                archivedAt: archivedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                required String title,
                required String repeatMode,
                Value<String?> repeatDays = const Value.absent(),
                required DateTime startDate,
                Value<DateTime?> endDate = const Value.absent(),
                Value<int?> reminderMinutesBefore = const Value.absent(),
                Value<bool> alarmEnabled = const Value.absent(),
                Value<String?> alarmConfigJson = const Value.absent(),
                Value<double?> caloriePerMinute = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TaskTemplatesCompanion.insert(
                id: id,
                type: type,
                title: title,
                repeatMode: repeatMode,
                repeatDays: repeatDays,
                startDate: startDate,
                endDate: endDate,
                reminderMinutesBefore: reminderMinutesBefore,
                alarmEnabled: alarmEnabled,
                alarmConfigJson: alarmConfigJson,
                caloriePerMinute: caloriePerMinute,
                archivedAt: archivedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskTemplatesTable, TaskTemplateRow>(table),
                  $$TaskTemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({taskInstancesRefs = false, scheduledAlarmsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskInstancesRefs) db.taskInstances,
                    if (scheduledAlarmsRefs) db.scheduledAlarms,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskInstancesRefs)
                        await $_getPrefetchedData<
                          TaskTemplateRow,
                          $TaskTemplatesTable,
                          TaskInstanceRow
                        >(
                          currentTable: table,
                          referencedTable: $$TaskTemplatesTableReferences
                              ._taskInstancesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TaskTemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).taskInstancesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.templateId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scheduledAlarmsRefs)
                        await $_getPrefetchedData<
                          TaskTemplateRow,
                          $TaskTemplatesTable,
                          ScheduledAlarmRow
                        >(
                          currentTable: table,
                          referencedTable: $$TaskTemplatesTableReferences
                              ._scheduledAlarmsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TaskTemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledAlarmsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TaskTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskTemplatesTable,
      TaskTemplateRow,
      $$TaskTemplatesTableFilterComposer,
      $$TaskTemplatesTableOrderingComposer,
      $$TaskTemplatesTableAnnotationComposer,
      $$TaskTemplatesTableCreateCompanionBuilder,
      $$TaskTemplatesTableUpdateCompanionBuilder,
      (TaskTemplateRow, $$TaskTemplatesTableReferences),
      TaskTemplateRow,
      PrefetchHooks Function({bool taskInstancesRefs, bool scheduledAlarmsRefs})
    >;
typedef $$TaskInstancesTableCreateCompanionBuilder =
    TaskInstancesCompanion Function({
      Value<int> id,
      required int templateId,
      required DateTime occurrenceDate,
      required String titleSnapshot,
      required String typeSnapshot,
      Value<double?> caloriePerMinuteSnapshot,
      required String status,
      Value<DateTime?> startedAt,
      Value<int> accumulatedSeconds,
      Value<DateTime?> completedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$TaskInstancesTableUpdateCompanionBuilder =
    TaskInstancesCompanion Function({
      Value<int> id,
      Value<int> templateId,
      Value<DateTime> occurrenceDate,
      Value<String> titleSnapshot,
      Value<String> typeSnapshot,
      Value<double?> caloriePerMinuteSnapshot,
      Value<String> status,
      Value<DateTime?> startedAt,
      Value<int> accumulatedSeconds,
      Value<DateTime?> completedAt,
      Value<DateTime?> deletedAt,
    });

final class $$TaskInstancesTableReferences
    extends
        BaseReferences<_$AppDatabase, $TaskInstancesTable, TaskInstanceRow> {
  $$TaskInstancesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TaskTemplatesTable _templateIdTable(_$AppDatabase db) => db
      .taskTemplates
      .createAlias('task_instances__template_id__task_templates__id');

  $$TaskTemplatesTableProcessedTableManager get templateId {
    final $_column = $_itemColumn<int>('template_id')!;

    final manager = $$TaskTemplatesTableTableManager(
      $_db,
      $_db.taskTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskInstancesTableFilterComposer
    extends Composer<_$AppDatabase, $TaskInstancesTable> {
  $$TaskInstancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleSnapshot => $composableBuilder(
    column: $table.titleSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typeSnapshot => $composableBuilder(
    column: $table.typeSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get caloriePerMinuteSnapshot => $composableBuilder(
    column: $table.caloriePerMinuteSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accumulatedSeconds => $composableBuilder(
    column: $table.accumulatedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TaskTemplatesTableFilterComposer get templateId {
    final $$TaskTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.taskTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.taskTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskInstancesTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskInstancesTable> {
  $$TaskInstancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleSnapshot => $composableBuilder(
    column: $table.titleSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typeSnapshot => $composableBuilder(
    column: $table.typeSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get caloriePerMinuteSnapshot => $composableBuilder(
    column: $table.caloriePerMinuteSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accumulatedSeconds => $composableBuilder(
    column: $table.accumulatedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TaskTemplatesTableOrderingComposer get templateId {
    final $$TaskTemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.taskTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.taskTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskInstancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskInstancesTable> {
  $$TaskInstancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleSnapshot => $composableBuilder(
    column: $table.titleSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get typeSnapshot => $composableBuilder(
    column: $table.typeSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<double> get caloriePerMinuteSnapshot => $composableBuilder(
    column: $table.caloriePerMinuteSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get accumulatedSeconds => $composableBuilder(
    column: $table.accumulatedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$TaskTemplatesTableAnnotationComposer get templateId {
    final $$TaskTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.taskTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskInstancesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskInstancesTable,
          TaskInstanceRow,
          $$TaskInstancesTableFilterComposer,
          $$TaskInstancesTableOrderingComposer,
          $$TaskInstancesTableAnnotationComposer,
          $$TaskInstancesTableCreateCompanionBuilder,
          $$TaskInstancesTableUpdateCompanionBuilder,
          (TaskInstanceRow, $$TaskInstancesTableReferences),
          TaskInstanceRow,
          PrefetchHooks Function({bool templateId})
        > {
  $$TaskInstancesTableTableManager(_$AppDatabase db, $TaskInstancesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskInstancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskInstancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskInstancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> templateId = const Value.absent(),
                Value<DateTime> occurrenceDate = const Value.absent(),
                Value<String> titleSnapshot = const Value.absent(),
                Value<String> typeSnapshot = const Value.absent(),
                Value<double?> caloriePerMinuteSnapshot = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<int> accumulatedSeconds = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => TaskInstancesCompanion(
                id: id,
                templateId: templateId,
                occurrenceDate: occurrenceDate,
                titleSnapshot: titleSnapshot,
                typeSnapshot: typeSnapshot,
                caloriePerMinuteSnapshot: caloriePerMinuteSnapshot,
                status: status,
                startedAt: startedAt,
                accumulatedSeconds: accumulatedSeconds,
                completedAt: completedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int templateId,
                required DateTime occurrenceDate,
                required String titleSnapshot,
                required String typeSnapshot,
                Value<double?> caloriePerMinuteSnapshot = const Value.absent(),
                required String status,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<int> accumulatedSeconds = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => TaskInstancesCompanion.insert(
                id: id,
                templateId: templateId,
                occurrenceDate: occurrenceDate,
                titleSnapshot: titleSnapshot,
                typeSnapshot: typeSnapshot,
                caloriePerMinuteSnapshot: caloriePerMinuteSnapshot,
                status: status,
                startedAt: startedAt,
                accumulatedSeconds: accumulatedSeconds,
                completedAt: completedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskInstancesTable, TaskInstanceRow>(table),
                  $$TaskInstancesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({templateId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (templateId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.templateId,
                                referencedTable: $$TaskInstancesTableReferences
                                    ._templateIdTable(db),
                                referencedColumn: $$TaskInstancesTableReferences
                                    ._templateIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TaskInstancesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskInstancesTable,
      TaskInstanceRow,
      $$TaskInstancesTableFilterComposer,
      $$TaskInstancesTableOrderingComposer,
      $$TaskInstancesTableAnnotationComposer,
      $$TaskInstancesTableCreateCompanionBuilder,
      $$TaskInstancesTableUpdateCompanionBuilder,
      (TaskInstanceRow, $$TaskInstancesTableReferences),
      TaskInstanceRow,
      PrefetchHooks Function({bool templateId})
    >;
typedef $$ScheduledAlarmsTableCreateCompanionBuilder =
    ScheduledAlarmsCompanion Function({
      Value<int> id,
      required int taskId,
      required int hour,
      required int minute,
      required String repeatRule,
      Value<String?> weekdays,
      Value<DateTime?> scheduledDate,
      Value<int?> advanceMinutes,
      Value<String> ringtone,
      Value<int> volume,
      Value<bool> snoozeEnabled,
      Value<int> snoozeMinutes,
      Value<String> tier,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ScheduledAlarmsTableUpdateCompanionBuilder =
    ScheduledAlarmsCompanion Function({
      Value<int> id,
      Value<int> taskId,
      Value<int> hour,
      Value<int> minute,
      Value<String> repeatRule,
      Value<String?> weekdays,
      Value<DateTime?> scheduledDate,
      Value<int?> advanceMinutes,
      Value<String> ringtone,
      Value<int> volume,
      Value<bool> snoozeEnabled,
      Value<int> snoozeMinutes,
      Value<String> tier,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ScheduledAlarmsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ScheduledAlarmsTable,
          ScheduledAlarmRow
        > {
  $$ScheduledAlarmsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TaskTemplatesTable _taskIdTable(_$AppDatabase db) => db.taskTemplates
      .createAlias('scheduled_alarms__task_id__task_templates__id');

  $$TaskTemplatesTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<int>('task_id')!;

    final manager = $$TaskTemplatesTableTableManager(
      $_db,
      $_db.taskTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScheduledAlarmsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledAlarmsTable> {
  $$ScheduledAlarmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get advanceMinutes => $composableBuilder(
    column: $table.advanceMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ringtone => $composableBuilder(
    column: $table.ringtone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get snoozeEnabled => $composableBuilder(
    column: $table.snoozeEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TaskTemplatesTableFilterComposer get taskId {
    final $$TaskTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.taskTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.taskTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledAlarmsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledAlarmsTable> {
  $$ScheduledAlarmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get advanceMinutes => $composableBuilder(
    column: $table.advanceMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ringtone => $composableBuilder(
    column: $table.ringtone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get snoozeEnabled => $composableBuilder(
    column: $table.snoozeEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TaskTemplatesTableOrderingComposer get taskId {
    final $$TaskTemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.taskTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.taskTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledAlarmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledAlarmsTable> {
  $$ScheduledAlarmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get advanceMinutes => $composableBuilder(
    column: $table.advanceMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ringtone =>
      $composableBuilder(column: $table.ringtone, builder: (column) => column);

  GeneratedColumn<int> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<bool> get snoozeEnabled => $composableBuilder(
    column: $table.snoozeEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TaskTemplatesTableAnnotationComposer get taskId {
    final $$TaskTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.taskTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledAlarmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledAlarmsTable,
          ScheduledAlarmRow,
          $$ScheduledAlarmsTableFilterComposer,
          $$ScheduledAlarmsTableOrderingComposer,
          $$ScheduledAlarmsTableAnnotationComposer,
          $$ScheduledAlarmsTableCreateCompanionBuilder,
          $$ScheduledAlarmsTableUpdateCompanionBuilder,
          (ScheduledAlarmRow, $$ScheduledAlarmsTableReferences),
          ScheduledAlarmRow,
          PrefetchHooks Function({bool taskId})
        > {
  $$ScheduledAlarmsTableTableManager(
    _$AppDatabase db,
    $ScheduledAlarmsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledAlarmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduledAlarmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduledAlarmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> taskId = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> minute = const Value.absent(),
                Value<String> repeatRule = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<DateTime?> scheduledDate = const Value.absent(),
                Value<int?> advanceMinutes = const Value.absent(),
                Value<String> ringtone = const Value.absent(),
                Value<int> volume = const Value.absent(),
                Value<bool> snoozeEnabled = const Value.absent(),
                Value<int> snoozeMinutes = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ScheduledAlarmsCompanion(
                id: id,
                taskId: taskId,
                hour: hour,
                minute: minute,
                repeatRule: repeatRule,
                weekdays: weekdays,
                scheduledDate: scheduledDate,
                advanceMinutes: advanceMinutes,
                ringtone: ringtone,
                volume: volume,
                snoozeEnabled: snoozeEnabled,
                snoozeMinutes: snoozeMinutes,
                tier: tier,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int taskId,
                required int hour,
                required int minute,
                required String repeatRule,
                Value<String?> weekdays = const Value.absent(),
                Value<DateTime?> scheduledDate = const Value.absent(),
                Value<int?> advanceMinutes = const Value.absent(),
                Value<String> ringtone = const Value.absent(),
                Value<int> volume = const Value.absent(),
                Value<bool> snoozeEnabled = const Value.absent(),
                Value<int> snoozeMinutes = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ScheduledAlarmsCompanion.insert(
                id: id,
                taskId: taskId,
                hour: hour,
                minute: minute,
                repeatRule: repeatRule,
                weekdays: weekdays,
                scheduledDate: scheduledDate,
                advanceMinutes: advanceMinutes,
                ringtone: ringtone,
                volume: volume,
                snoozeEnabled: snoozeEnabled,
                snoozeMinutes: snoozeMinutes,
                tier: tier,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScheduledAlarmsTable, ScheduledAlarmRow>(table),
                  $$ScheduledAlarmsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable:
                                    $$ScheduledAlarmsTableReferences
                                        ._taskIdTable(db),
                                referencedColumn:
                                    $$ScheduledAlarmsTableReferences
                                        ._taskIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ScheduledAlarmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledAlarmsTable,
      ScheduledAlarmRow,
      $$ScheduledAlarmsTableFilterComposer,
      $$ScheduledAlarmsTableOrderingComposer,
      $$ScheduledAlarmsTableAnnotationComposer,
      $$ScheduledAlarmsTableCreateCompanionBuilder,
      $$ScheduledAlarmsTableUpdateCompanionBuilder,
      (ScheduledAlarmRow, $$ScheduledAlarmsTableReferences),
      ScheduledAlarmRow,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$DiariesTableCreateCompanionBuilder =
    DiariesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> content,
      Value<String> templateType,
      Value<double> fontSize,
      Value<String?> fontFamily,
      Value<String?> coverPath,
      required DateTime diaryDate,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$DiariesTableUpdateCompanionBuilder =
    DiariesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> content,
      Value<String> templateType,
      Value<double> fontSize,
      Value<String?> fontFamily,
      Value<String?> coverPath,
      Value<DateTime> diaryDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
    });

class $$DiariesTableFilterComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateType => $composableBuilder(
    column: $table.templateType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fontSize => $composableBuilder(
    column: $table.fontSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get diaryDate => $composableBuilder(
    column: $table.diaryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiariesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateType => $composableBuilder(
    column: $table.templateType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fontSize => $composableBuilder(
    column: $table.fontSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get diaryDate => $composableBuilder(
    column: $table.diaryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get templateType => $composableBuilder(
    column: $table.templateType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fontSize =>
      $composableBuilder(column: $table.fontSize, builder: (column) => column);

  GeneratedColumn<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<DateTime> get diaryDate =>
      $composableBuilder(column: $table.diaryDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DiariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiariesTable,
          Diary,
          $$DiariesTableFilterComposer,
          $$DiariesTableOrderingComposer,
          $$DiariesTableAnnotationComposer,
          $$DiariesTableCreateCompanionBuilder,
          $$DiariesTableUpdateCompanionBuilder,
          (Diary, BaseReferences<_$AppDatabase, $DiariesTable, Diary>),
          Diary,
          PrefetchHooks Function()
        > {
  $$DiariesTableTableManager(_$AppDatabase db, $DiariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> templateType = const Value.absent(),
                Value<double> fontSize = const Value.absent(),
                Value<String?> fontFamily = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime> diaryDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => DiariesCompanion(
                id: id,
                title: title,
                content: content,
                templateType: templateType,
                fontSize: fontSize,
                fontFamily: fontFamily,
                coverPath: coverPath,
                diaryDate: diaryDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> templateType = const Value.absent(),
                Value<double> fontSize = const Value.absent(),
                Value<String?> fontFamily = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                required DateTime diaryDate,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => DiariesCompanion.insert(
                id: id,
                title: title,
                content: content,
                templateType: templateType,
                fontSize: fontSize,
                fontFamily: fontFamily,
                coverPath: coverPath,
                diaryDate: diaryDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiariesTable, Diary>(table),
                  BaseReferences<_$AppDatabase, $DiariesTable, Diary>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiariesTable,
      Diary,
      $$DiariesTableFilterComposer,
      $$DiariesTableOrderingComposer,
      $$DiariesTableAnnotationComposer,
      $$DiariesTableCreateCompanionBuilder,
      $$DiariesTableUpdateCompanionBuilder,
      (Diary, BaseReferences<_$AppDatabase, $DiariesTable, Diary>),
      Diary,
      PrefetchHooks Function()
    >;
typedef $$MemosTableCreateCompanionBuilder =
    MemosCompanion Function({
      Value<int> id,
      required String content,
      Value<bool> pinned,
      Value<String?> color,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$MemosTableUpdateCompanionBuilder =
    MemosCompanion Function({
      Value<int> id,
      Value<String> content,
      Value<bool> pinned,
      Value<String?> color,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
    });

class $$MemosTableFilterComposer extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemosTableOrderingComposer
    extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemosTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$MemosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemosTable,
          Memo,
          $$MemosTableFilterComposer,
          $$MemosTableOrderingComposer,
          $$MemosTableAnnotationComposer,
          $$MemosTableCreateCompanionBuilder,
          $$MemosTableUpdateCompanionBuilder,
          (Memo, BaseReferences<_$AppDatabase, $MemosTable, Memo>),
          Memo,
          PrefetchHooks Function()
        > {
  $$MemosTableTableManager(_$AppDatabase db, $MemosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => MemosCompanion(
                id: id,
                content: content,
                pinned: pinned,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String content,
                Value<bool> pinned = const Value.absent(),
                Value<String?> color = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => MemosCompanion.insert(
                id: id,
                content: content,
                pinned: pinned,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MemosTable, Memo>(table),
                  BaseReferences<_$AppDatabase, $MemosTable, Memo>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemosTable,
      Memo,
      $$MemosTableFilterComposer,
      $$MemosTableOrderingComposer,
      $$MemosTableAnnotationComposer,
      $$MemosTableCreateCompanionBuilder,
      $$MemosTableUpdateCompanionBuilder,
      (Memo, BaseReferences<_$AppDatabase, $MemosTable, Memo>),
      Memo,
      PrefetchHooks Function()
    >;
typedef $$ShoppingItemsTableCreateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> quantity,
      Value<String?> category,
      Value<bool> checked,
      required DateTime createdAt,
      Value<DateTime?> checkedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$ShoppingItemsTableUpdateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> quantity,
      Value<String?> category,
      Value<bool> checked,
      Value<DateTime> createdAt,
      Value<DateTime?> checkedAt,
      Value<DateTime?> deletedAt,
    });

class $$ShoppingItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get checked => $composableBuilder(
    column: $table.checked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShoppingItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get checked => $composableBuilder(
    column: $table.checked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShoppingItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get checked =>
      $composableBuilder(column: $table.checked, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ShoppingItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShoppingItemsTable,
          ShoppingItem,
          $$ShoppingItemsTableFilterComposer,
          $$ShoppingItemsTableOrderingComposer,
          $$ShoppingItemsTableAnnotationComposer,
          $$ShoppingItemsTableCreateCompanionBuilder,
          $$ShoppingItemsTableUpdateCompanionBuilder,
          (
            ShoppingItem,
            BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItem>,
          ),
          ShoppingItem,
          PrefetchHooks Function()
        > {
  $$ShoppingItemsTableTableManager(_$AppDatabase db, $ShoppingItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<bool> checked = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> checkedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => ShoppingItemsCompanion(
                id: id,
                name: name,
                quantity: quantity,
                category: category,
                checked: checked,
                createdAt: createdAt,
                checkedAt: checkedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> quantity = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<bool> checked = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> checkedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => ShoppingItemsCompanion.insert(
                id: id,
                name: name,
                quantity: quantity,
                category: category,
                checked: checked,
                createdAt: createdAt,
                checkedAt: checkedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShoppingItemsTable, ShoppingItem>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ShoppingItemsTable,
                    ShoppingItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShoppingItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShoppingItemsTable,
      ShoppingItem,
      $$ShoppingItemsTableFilterComposer,
      $$ShoppingItemsTableOrderingComposer,
      $$ShoppingItemsTableAnnotationComposer,
      $$ShoppingItemsTableCreateCompanionBuilder,
      $$ShoppingItemsTableUpdateCompanionBuilder,
      (
        ShoppingItem,
        BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItem>,
      ),
      ShoppingItem,
      PrefetchHooks Function()
    >;
typedef $$BirthdaysTableCreateCompanionBuilder =
    BirthdaysCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> birthdayYear,
      required int birthdayMonth,
      required int birthdayDay,
      Value<String> calendarType,
      Value<String?> groupTag,
      Value<int> advanceDays,
      Value<String?> notes,
      required DateTime createdAt,
      Value<DateTime?> deletedAt,
    });
typedef $$BirthdaysTableUpdateCompanionBuilder =
    BirthdaysCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> birthdayYear,
      Value<int> birthdayMonth,
      Value<int> birthdayDay,
      Value<String> calendarType,
      Value<String?> groupTag,
      Value<int> advanceDays,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
    });

class $$BirthdaysTableFilterComposer
    extends Composer<_$AppDatabase, $BirthdaysTable> {
  $$BirthdaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthdayYear => $composableBuilder(
    column: $table.birthdayYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthdayMonth => $composableBuilder(
    column: $table.birthdayMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthdayDay => $composableBuilder(
    column: $table.birthdayDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get calendarType => $composableBuilder(
    column: $table.calendarType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupTag => $composableBuilder(
    column: $table.groupTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get advanceDays => $composableBuilder(
    column: $table.advanceDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BirthdaysTableOrderingComposer
    extends Composer<_$AppDatabase, $BirthdaysTable> {
  $$BirthdaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthdayYear => $composableBuilder(
    column: $table.birthdayYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthdayMonth => $composableBuilder(
    column: $table.birthdayMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthdayDay => $composableBuilder(
    column: $table.birthdayDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get calendarType => $composableBuilder(
    column: $table.calendarType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupTag => $composableBuilder(
    column: $table.groupTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get advanceDays => $composableBuilder(
    column: $table.advanceDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BirthdaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $BirthdaysTable> {
  $$BirthdaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get birthdayYear => $composableBuilder(
    column: $table.birthdayYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get birthdayMonth => $composableBuilder(
    column: $table.birthdayMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get birthdayDay => $composableBuilder(
    column: $table.birthdayDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get calendarType => $composableBuilder(
    column: $table.calendarType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupTag =>
      $composableBuilder(column: $table.groupTag, builder: (column) => column);

  GeneratedColumn<int> get advanceDays => $composableBuilder(
    column: $table.advanceDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$BirthdaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BirthdaysTable,
          Birthday,
          $$BirthdaysTableFilterComposer,
          $$BirthdaysTableOrderingComposer,
          $$BirthdaysTableAnnotationComposer,
          $$BirthdaysTableCreateCompanionBuilder,
          $$BirthdaysTableUpdateCompanionBuilder,
          (Birthday, BaseReferences<_$AppDatabase, $BirthdaysTable, Birthday>),
          Birthday,
          PrefetchHooks Function()
        > {
  $$BirthdaysTableTableManager(_$AppDatabase db, $BirthdaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BirthdaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BirthdaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BirthdaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> birthdayYear = const Value.absent(),
                Value<int> birthdayMonth = const Value.absent(),
                Value<int> birthdayDay = const Value.absent(),
                Value<String> calendarType = const Value.absent(),
                Value<String?> groupTag = const Value.absent(),
                Value<int> advanceDays = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => BirthdaysCompanion(
                id: id,
                name: name,
                birthdayYear: birthdayYear,
                birthdayMonth: birthdayMonth,
                birthdayDay: birthdayDay,
                calendarType: calendarType,
                groupTag: groupTag,
                advanceDays: advanceDays,
                notes: notes,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> birthdayYear = const Value.absent(),
                required int birthdayMonth,
                required int birthdayDay,
                Value<String> calendarType = const Value.absent(),
                Value<String?> groupTag = const Value.absent(),
                Value<int> advanceDays = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => BirthdaysCompanion.insert(
                id: id,
                name: name,
                birthdayYear: birthdayYear,
                birthdayMonth: birthdayMonth,
                birthdayDay: birthdayDay,
                calendarType: calendarType,
                groupTag: groupTag,
                advanceDays: advanceDays,
                notes: notes,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BirthdaysTable, Birthday>(table),
                  BaseReferences<_$AppDatabase, $BirthdaysTable, Birthday>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BirthdaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BirthdaysTable,
      Birthday,
      $$BirthdaysTableFilterComposer,
      $$BirthdaysTableOrderingComposer,
      $$BirthdaysTableAnnotationComposer,
      $$BirthdaysTableCreateCompanionBuilder,
      $$BirthdaysTableUpdateCompanionBuilder,
      (Birthday, BaseReferences<_$AppDatabase, $BirthdaysTable, Birthday>),
      Birthday,
      PrefetchHooks Function()
    >;
typedef $$CalorieEntriesTableCreateCompanionBuilder =
    CalorieEntriesCompanion Function({
      Value<int> id,
      required DateTime entryDate,
      required String meal,
      required String name,
      required int kcal,
      Value<double> proteinG,
      Value<double> carbG,
      Value<double> fatG,
      required DateTime createdAt,
      Value<DateTime?> deletedAt,
    });
typedef $$CalorieEntriesTableUpdateCompanionBuilder =
    CalorieEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> entryDate,
      Value<String> meal,
      Value<String> name,
      Value<int> kcal,
      Value<double> proteinG,
      Value<double> carbG,
      Value<double> fatG,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
    });

class $$CalorieEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CalorieEntriesTable> {
  $$CalorieEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get entryDate => $composableBuilder(
    column: $table.entryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meal => $composableBuilder(
    column: $table.meal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbG => $composableBuilder(
    column: $table.carbG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalorieEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CalorieEntriesTable> {
  $$CalorieEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get entryDate => $composableBuilder(
    column: $table.entryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meal => $composableBuilder(
    column: $table.meal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbG => $composableBuilder(
    column: $table.carbG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalorieEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalorieEntriesTable> {
  $$CalorieEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get entryDate =>
      $composableBuilder(column: $table.entryDate, builder: (column) => column);

  GeneratedColumn<String> get meal =>
      $composableBuilder(column: $table.meal, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get proteinG =>
      $composableBuilder(column: $table.proteinG, builder: (column) => column);

  GeneratedColumn<double> get carbG =>
      $composableBuilder(column: $table.carbG, builder: (column) => column);

  GeneratedColumn<double> get fatG =>
      $composableBuilder(column: $table.fatG, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CalorieEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalorieEntriesTable,
          CalorieEntry,
          $$CalorieEntriesTableFilterComposer,
          $$CalorieEntriesTableOrderingComposer,
          $$CalorieEntriesTableAnnotationComposer,
          $$CalorieEntriesTableCreateCompanionBuilder,
          $$CalorieEntriesTableUpdateCompanionBuilder,
          (
            CalorieEntry,
            BaseReferences<_$AppDatabase, $CalorieEntriesTable, CalorieEntry>,
          ),
          CalorieEntry,
          PrefetchHooks Function()
        > {
  $$CalorieEntriesTableTableManager(
    _$AppDatabase db,
    $CalorieEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalorieEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalorieEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalorieEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> entryDate = const Value.absent(),
                Value<String> meal = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> kcal = const Value.absent(),
                Value<double> proteinG = const Value.absent(),
                Value<double> carbG = const Value.absent(),
                Value<double> fatG = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => CalorieEntriesCompanion(
                id: id,
                entryDate: entryDate,
                meal: meal,
                name: name,
                kcal: kcal,
                proteinG: proteinG,
                carbG: carbG,
                fatG: fatG,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime entryDate,
                required String meal,
                required String name,
                required int kcal,
                Value<double> proteinG = const Value.absent(),
                Value<double> carbG = const Value.absent(),
                Value<double> fatG = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => CalorieEntriesCompanion.insert(
                id: id,
                entryDate: entryDate,
                meal: meal,
                name: name,
                kcal: kcal,
                proteinG: proteinG,
                carbG: carbG,
                fatG: fatG,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CalorieEntriesTable, CalorieEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CalorieEntriesTable,
                    CalorieEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalorieEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalorieEntriesTable,
      CalorieEntry,
      $$CalorieEntriesTableFilterComposer,
      $$CalorieEntriesTableOrderingComposer,
      $$CalorieEntriesTableAnnotationComposer,
      $$CalorieEntriesTableCreateCompanionBuilder,
      $$CalorieEntriesTableUpdateCompanionBuilder,
      (
        CalorieEntry,
        BaseReferences<_$AppDatabase, $CalorieEntriesTable, CalorieEntry>,
      ),
      CalorieEntry,
      PrefetchHooks Function()
    >;
typedef $$LocationRemindersTableCreateCompanionBuilder =
    LocationRemindersCompanion Function({
      Value<int> id,
      required String title,
      required String placeName,
      required double latitude,
      required double longitude,
      Value<int> radiusMeters,
      Value<String> triggerOn,
      Value<bool> enabled,
      Value<DateTime?> notifiedAt,
      required DateTime createdAt,
      Value<DateTime?> deletedAt,
    });
typedef $$LocationRemindersTableUpdateCompanionBuilder =
    LocationRemindersCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> placeName,
      Value<double> latitude,
      Value<double> longitude,
      Value<int> radiusMeters,
      Value<String> triggerOn,
      Value<bool> enabled,
      Value<DateTime?> notifiedAt,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
    });

class $$LocationRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $LocationRemindersTable> {
  $$LocationRemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get placeName => $composableBuilder(
    column: $table.placeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerOn => $composableBuilder(
    column: $table.triggerOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get notifiedAt => $composableBuilder(
    column: $table.notifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationRemindersTable> {
  $$LocationRemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get placeName => $composableBuilder(
    column: $table.placeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerOn => $composableBuilder(
    column: $table.triggerOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get notifiedAt => $composableBuilder(
    column: $table.notifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationRemindersTable> {
  $$LocationRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get placeName =>
      $composableBuilder(column: $table.placeName, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggerOn =>
      $composableBuilder(column: $table.triggerOn, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get notifiedAt => $composableBuilder(
    column: $table.notifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocationRemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationRemindersTable,
          LocationReminder,
          $$LocationRemindersTableFilterComposer,
          $$LocationRemindersTableOrderingComposer,
          $$LocationRemindersTableAnnotationComposer,
          $$LocationRemindersTableCreateCompanionBuilder,
          $$LocationRemindersTableUpdateCompanionBuilder,
          (
            LocationReminder,
            BaseReferences<
              _$AppDatabase,
              $LocationRemindersTable,
              LocationReminder
            >,
          ),
          LocationReminder,
          PrefetchHooks Function()
        > {
  $$LocationRemindersTableTableManager(
    _$AppDatabase db,
    $LocationRemindersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationRemindersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> placeName = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<int> radiusMeters = const Value.absent(),
                Value<String> triggerOn = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime?> notifiedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => LocationRemindersCompanion(
                id: id,
                title: title,
                placeName: placeName,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                triggerOn: triggerOn,
                enabled: enabled,
                notifiedAt: notifiedAt,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String placeName,
                required double latitude,
                required double longitude,
                Value<int> radiusMeters = const Value.absent(),
                Value<String> triggerOn = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime?> notifiedAt = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => LocationRemindersCompanion.insert(
                id: id,
                title: title,
                placeName: placeName,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                triggerOn: triggerOn,
                enabled: enabled,
                notifiedAt: notifiedAt,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocationRemindersTable, LocationReminder>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocationRemindersTable,
                    LocationReminder
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationRemindersTable,
      LocationReminder,
      $$LocationRemindersTableFilterComposer,
      $$LocationRemindersTableOrderingComposer,
      $$LocationRemindersTableAnnotationComposer,
      $$LocationRemindersTableCreateCompanionBuilder,
      $$LocationRemindersTableUpdateCompanionBuilder,
      (
        LocationReminder,
        BaseReferences<
          _$AppDatabase,
          $LocationRemindersTable,
          LocationReminder
        >,
      ),
      LocationReminder,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TaskTemplatesTableTableManager get taskTemplates =>
      $$TaskTemplatesTableTableManager(_db, _db.taskTemplates);
  $$TaskInstancesTableTableManager get taskInstances =>
      $$TaskInstancesTableTableManager(_db, _db.taskInstances);
  $$ScheduledAlarmsTableTableManager get scheduledAlarms =>
      $$ScheduledAlarmsTableTableManager(_db, _db.scheduledAlarms);
  $$DiariesTableTableManager get diaries =>
      $$DiariesTableTableManager(_db, _db.diaries);
  $$MemosTableTableManager get memos =>
      $$MemosTableTableManager(_db, _db.memos);
  $$ShoppingItemsTableTableManager get shoppingItems =>
      $$ShoppingItemsTableTableManager(_db, _db.shoppingItems);
  $$BirthdaysTableTableManager get birthdays =>
      $$BirthdaysTableTableManager(_db, _db.birthdays);
  $$CalorieEntriesTableTableManager get calorieEntries =>
      $$CalorieEntriesTableTableManager(_db, _db.calorieEntries);
  $$LocationRemindersTableTableManager get locationReminders =>
      $$LocationRemindersTableTableManager(_db, _db.locationReminders);
}
