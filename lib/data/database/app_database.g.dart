// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<int> recordedAt = GeneratedColumn<int>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzIdMeta = const VerificationMeta('tzId');
  @override
  late final GeneratedColumn<String> tzId = GeneratedColumn<String>(
    'tz_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzOffsetMinMeta = const VerificationMeta(
    'tzOffsetMin',
  );
  @override
  late final GeneratedColumn<int> tzOffsetMin = GeneratedColumn<int>(
    'tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
    'subject_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    occurredAt,
    recordedAt,
    localDate,
    tzId,
    tzOffsetMin,
    subjectType,
    subjectId,
    payload,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<Event> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('tz_id')) {
      context.handle(
        _tzIdMeta,
        tzId.isAcceptableOrUnknown(data['tz_id']!, _tzIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tzIdMeta);
    }
    if (data.containsKey('tz_offset_min')) {
      context.handle(
        _tzOffsetMinMeta,
        tzOffsetMin.isAcceptableOrUnknown(
          data['tz_offset_min']!,
          _tzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMinMeta);
    }
    if (data.containsKey('subject_type')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subject_type']!,
          _subjectTypeMeta,
        ),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      tzId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz_id'],
      )!,
      tzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset_min'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_type'],
      ),
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class Event extends DataClass implements Insertable<Event> {
  /// Primary key UUID string.
  final String id;

  /// Event type string (see EventTypes constants, SPEC.md §2.2).
  final String type;

  /// UTC epoch milliseconds when the event actually occurred.
  final int occurredAt;

  /// UTC epoch milliseconds when the event was recorded in the database.
  /// (Differs from occurredAt for manual entries).
  final int recordedAt;

  /// Logical date in YYYY-MM-DD format per SPEC.md §1.2.
  /// Computed once at write time: (local_datetime - day_start_offset).date. Never recomputed.
  final String localDate;

  /// IANA timezone identifier at write time (e.g. 'America/Edmonton').
  final String tzId;

  /// Timezone offset in minutes at write time.
  final int tzOffsetMin;

  /// Subject type: 'session' | 'task' | 'habit' | null.
  final String? subjectType;

  /// Subject primary key ID, or null for events with no subject.
  final String? subjectId;

  /// JSON-encoded type-specific payload.
  final String payload;

  /// Device ID of the installation that logged this event (§4, §5).
  final String deviceId;
  const Event({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.recordedAt,
    required this.localDate,
    required this.tzId,
    required this.tzOffsetMin,
    this.subjectType,
    this.subjectId,
    required this.payload,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['occurred_at'] = Variable<int>(occurredAt);
    map['recorded_at'] = Variable<int>(recordedAt);
    map['local_date'] = Variable<String>(localDate);
    map['tz_id'] = Variable<String>(tzId);
    map['tz_offset_min'] = Variable<int>(tzOffsetMin);
    if (!nullToAbsent || subjectType != null) {
      map['subject_type'] = Variable<String>(subjectType);
    }
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    map['payload'] = Variable<String>(payload);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      type: Value(type),
      occurredAt: Value(occurredAt),
      recordedAt: Value(recordedAt),
      localDate: Value(localDate),
      tzId: Value(tzId),
      tzOffsetMin: Value(tzOffsetMin),
      subjectType: subjectType == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectType),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
      payload: Value(payload),
      deviceId: Value(deviceId),
    );
  }

  factory Event.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      occurredAt: serializer.fromJson<int>(json['occurred_at']),
      recordedAt: serializer.fromJson<int>(json['recorded_at']),
      localDate: serializer.fromJson<String>(json['local_date']),
      tzId: serializer.fromJson<String>(json['tz_id']),
      tzOffsetMin: serializer.fromJson<int>(json['tz_offset_min']),
      subjectType: serializer.fromJson<String?>(json['subject_type']),
      subjectId: serializer.fromJson<String?>(json['subject_id']),
      payload: serializer.fromJson<String>(json['payload']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'occurred_at': serializer.toJson<int>(occurredAt),
      'recorded_at': serializer.toJson<int>(recordedAt),
      'local_date': serializer.toJson<String>(localDate),
      'tz_id': serializer.toJson<String>(tzId),
      'tz_offset_min': serializer.toJson<int>(tzOffsetMin),
      'subject_type': serializer.toJson<String?>(subjectType),
      'subject_id': serializer.toJson<String?>(subjectId),
      'payload': serializer.toJson<String>(payload),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  Event copyWith({
    String? id,
    String? type,
    int? occurredAt,
    int? recordedAt,
    String? localDate,
    String? tzId,
    int? tzOffsetMin,
    Value<String?> subjectType = const Value.absent(),
    Value<String?> subjectId = const Value.absent(),
    String? payload,
    String? deviceId,
  }) => Event(
    id: id ?? this.id,
    type: type ?? this.type,
    occurredAt: occurredAt ?? this.occurredAt,
    recordedAt: recordedAt ?? this.recordedAt,
    localDate: localDate ?? this.localDate,
    tzId: tzId ?? this.tzId,
    tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
    subjectType: subjectType.present ? subjectType.value : this.subjectType,
    subjectId: subjectId.present ? subjectId.value : this.subjectId,
    payload: payload ?? this.payload,
    deviceId: deviceId ?? this.deviceId,
  );
  Event copyWithCompanion(EventsCompanion data) {
    return Event(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      tzId: data.tzId.present ? data.tzId.value : this.tzId,
      tzOffsetMin: data.tzOffsetMin.present
          ? data.tzOffsetMin.value
          : this.tzOffsetMin,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      payload: data.payload.present ? data.payload.value : this.payload,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('localDate: $localDate, ')
          ..write('tzId: $tzId, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('payload: $payload, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    occurredAt,
    recordedAt,
    localDate,
    tzId,
    tzOffsetMin,
    subjectType,
    subjectId,
    payload,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          other.id == this.id &&
          other.type == this.type &&
          other.occurredAt == this.occurredAt &&
          other.recordedAt == this.recordedAt &&
          other.localDate == this.localDate &&
          other.tzId == this.tzId &&
          other.tzOffsetMin == this.tzOffsetMin &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.payload == this.payload &&
          other.deviceId == this.deviceId);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<String> id;
  final Value<String> type;
  final Value<int> occurredAt;
  final Value<int> recordedAt;
  final Value<String> localDate;
  final Value<String> tzId;
  final Value<int> tzOffsetMin;
  final Value<String?> subjectType;
  final Value<String?> subjectId;
  final Value<String> payload;
  final Value<String> deviceId;
  final Value<int> rowid;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.localDate = const Value.absent(),
    this.tzId = const Value.absent(),
    this.tzOffsetMin = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.payload = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required String id,
    required String type,
    required int occurredAt,
    required int recordedAt,
    required String localDate,
    required String tzId,
    required int tzOffsetMin,
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    required String payload,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       occurredAt = Value(occurredAt),
       recordedAt = Value(recordedAt),
       localDate = Value(localDate),
       tzId = Value(tzId),
       tzOffsetMin = Value(tzOffsetMin),
       payload = Value(payload),
       deviceId = Value(deviceId);
  static Insertable<Event> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<int>? occurredAt,
    Expression<int>? recordedAt,
    Expression<String>? localDate,
    Expression<String>? tzId,
    Expression<int>? tzOffsetMin,
    Expression<String>? subjectType,
    Expression<String>? subjectId,
    Expression<String>? payload,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (localDate != null) 'local_date': localDate,
      if (tzId != null) 'tz_id': tzId,
      if (tzOffsetMin != null) 'tz_offset_min': tzOffsetMin,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (payload != null) 'payload': payload,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<int>? occurredAt,
    Value<int>? recordedAt,
    Value<String>? localDate,
    Value<String>? tzId,
    Value<int>? tzOffsetMin,
    Value<String?>? subjectType,
    Value<String?>? subjectId,
    Value<String>? payload,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      recordedAt: recordedAt ?? this.recordedAt,
      localDate: localDate ?? this.localDate,
      tzId: tzId ?? this.tzId,
      tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      payload: payload ?? this.payload,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<int>(recordedAt.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (tzId.present) {
      map['tz_id'] = Variable<String>(tzId.value);
    }
    if (tzOffsetMin.present) {
      map['tz_offset_min'] = Variable<int>(tzOffsetMin.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('localDate: $localDate, ')
          ..write('tzId: $tzId, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('payload: $payload, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FocusSessionsTable extends FocusSessions
    with TableInfo<$FocusSessionsTable, FocusSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plannedDurationSMeta = const VerificationMeta(
    'plannedDurationS',
  );
  @override
  late final GeneratedColumn<int> plannedDurationS = GeneratedColumn<int>(
    'planned_duration_s',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _actualDurationSMeta = const VerificationMeta(
    'actualDurationS',
  );
  @override
  late final GeneratedColumn<int> actualDurationS = GeneratedColumn<int>(
    'actual_duration_s',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzOffsetMinMeta = const VerificationMeta(
    'tzOffsetMin',
  );
  @override
  late final GeneratedColumn<int> tzOffsetMin = GeneratedColumn<int>(
    'tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzIdMeta = const VerificationMeta('tzId');
  @override
  late final GeneratedColumn<String> tzId = GeneratedColumn<String>(
    'tz_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interruptionsInternalMeta =
      const VerificationMeta('interruptionsInternal');
  @override
  late final GeneratedColumn<int> interruptionsInternal = GeneratedColumn<int>(
    'interruptions_internal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _interruptionsExternalMeta =
      const VerificationMeta('interruptionsExternal');
  @override
  late final GeneratedColumn<int> interruptionsExternal = GeneratedColumn<int>(
    'interruptions_external',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _focusRatingMeta = const VerificationMeta(
    'focusRating',
  );
  @override
  late final GeneratedColumn<int> focusRating = GeneratedColumn<int>(
    'focus_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isManualMeta = const VerificationMeta(
    'isManual',
  );
  @override
  late final GeneratedColumn<bool> isManual = GeneratedColumn<bool>(
    'is_manual',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_manual" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    projectId,
    mode,
    plannedDurationS,
    actualDurationS,
    startedAt,
    endedAt,
    localDate,
    tzOffsetMin,
    tzId,
    outcome,
    interruptionsInternal,
    interruptionsExternal,
    focusRating,
    note,
    isManual,
    updatedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FocusSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('planned_duration_s')) {
      context.handle(
        _plannedDurationSMeta,
        plannedDurationS.isAcceptableOrUnknown(
          data['planned_duration_s']!,
          _plannedDurationSMeta,
        ),
      );
    }
    if (data.containsKey('actual_duration_s')) {
      context.handle(
        _actualDurationSMeta,
        actualDurationS.isAcceptableOrUnknown(
          data['actual_duration_s']!,
          _actualDurationSMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('tz_offset_min')) {
      context.handle(
        _tzOffsetMinMeta,
        tzOffsetMin.isAcceptableOrUnknown(
          data['tz_offset_min']!,
          _tzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMinMeta);
    }
    if (data.containsKey('tz_id')) {
      context.handle(
        _tzIdMeta,
        tzId.isAcceptableOrUnknown(data['tz_id']!, _tzIdMeta),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('interruptions_internal')) {
      context.handle(
        _interruptionsInternalMeta,
        interruptionsInternal.isAcceptableOrUnknown(
          data['interruptions_internal']!,
          _interruptionsInternalMeta,
        ),
      );
    }
    if (data.containsKey('interruptions_external')) {
      context.handle(
        _interruptionsExternalMeta,
        interruptionsExternal.isAcceptableOrUnknown(
          data['interruptions_external']!,
          _interruptionsExternalMeta,
        ),
      );
    }
    if (data.containsKey('focus_rating')) {
      context.handle(
        _focusRatingMeta,
        focusRating.isAcceptableOrUnknown(
          data['focus_rating']!,
          _focusRatingMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_manual')) {
      context.handle(
        _isManualMeta,
        isManual.isAcceptableOrUnknown(data['is_manual']!, _isManualMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      plannedDurationS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_duration_s'],
      )!,
      actualDurationS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_duration_s'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      tzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset_min'],
      )!,
      tzId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz_id'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      interruptionsInternal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interruptions_internal'],
      )!,
      interruptionsExternal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interruptions_external'],
      )!,
      focusRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_rating'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      isManual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_manual'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $FocusSessionsTable createAlias(String alias) {
    return $FocusSessionsTable(attachedDatabase, alias);
  }
}

class FocusSession extends DataClass implements Insertable<FocusSession> {
  /// Session identifier (UUID string).
  final String id;

  /// Associated task ID, if any.
  final String? taskId;

  /// Denormalized from task at start so later reassignment doesn't rewrite history.
  final String? projectId;

  /// 'pomodoro' | 'flow'
  final String mode;

  /// Planned duration in seconds (0 for flow mode).
  final int plannedDurationS;

  /// Actual duration in seconds, excluding paused time.
  final int actualDurationS;

  /// Start timestamp in UTC epoch milliseconds.
  final int startedAt;

  /// End timestamp in UTC epoch milliseconds.
  final int endedAt;

  /// Logical date in YYYY-MM-DD per session start.
  final String localDate;

  /// Timezone offset in minutes east of UTC, captured at session START
  /// (SPEC.md §1.2). +330 in India, −360 in Alberta during summer.
  ///
  /// Carried on the session, not looked up when reading, because §4.4 bins
  /// sessions by local hour and the answer must not depend on where the phone
  /// is today. Without this column, flying from Ahmedabad to Edmonton moves
  /// every session ever recorded by 11½ hours and turns a morning habit into a
  /// late-night one.
  /// Required, with no default, on purpose. A default of 0 would be UTC, and a
  /// session that quietly claims to have happened in UTC is a wrong answer that
  /// nothing complains about. Required means the compiler asks every caller
  /// where the session happened.
  final int tzOffsetMin;

  /// IANA zone id at session start, e.g. `Asia/Kolkata`, `America/Edmonton`.
  ///
  /// Not used for any calculation — [tzOffsetMin] carries that. This is for
  /// showing "9am, Kolkata time" beside a session, and for diagnosing a
  /// timezone bug six months from now when the offset alone is not enough to
  /// tell you what happened.
  final String tzId;

  /// 'completed' | 'abandoned'
  final String outcome;

  /// Count of internal interruptions.
  final int interruptionsInternal;

  /// Count of external interruptions.
  final int interruptionsExternal;

  /// User rating 1–5, null if unrated.
  final int? focusRating;

  /// Optional session note.
  final String? note;

  /// Whether this session was logged retroactively (0 = normal, 1 = manual).
  final bool isManual;

  /// UTC epoch milliseconds, written on every update (§4).
  final int updatedAt;

  /// Which install made the last write (§4, §5).
  final String deviceId;
  const FocusSession({
    required this.id,
    this.taskId,
    this.projectId,
    required this.mode,
    required this.plannedDurationS,
    required this.actualDurationS,
    required this.startedAt,
    required this.endedAt,
    required this.localDate,
    required this.tzOffsetMin,
    required this.tzId,
    required this.outcome,
    required this.interruptionsInternal,
    required this.interruptionsExternal,
    this.focusRating,
    this.note,
    required this.isManual,
    required this.updatedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['mode'] = Variable<String>(mode);
    map['planned_duration_s'] = Variable<int>(plannedDurationS);
    map['actual_duration_s'] = Variable<int>(actualDurationS);
    map['started_at'] = Variable<int>(startedAt);
    map['ended_at'] = Variable<int>(endedAt);
    map['local_date'] = Variable<String>(localDate);
    map['tz_offset_min'] = Variable<int>(tzOffsetMin);
    map['tz_id'] = Variable<String>(tzId);
    map['outcome'] = Variable<String>(outcome);
    map['interruptions_internal'] = Variable<int>(interruptionsInternal);
    map['interruptions_external'] = Variable<int>(interruptionsExternal);
    if (!nullToAbsent || focusRating != null) {
      map['focus_rating'] = Variable<int>(focusRating);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_manual'] = Variable<bool>(isManual);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  FocusSessionsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionsCompanion(
      id: Value(id),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      mode: Value(mode),
      plannedDurationS: Value(plannedDurationS),
      actualDurationS: Value(actualDurationS),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      localDate: Value(localDate),
      tzOffsetMin: Value(tzOffsetMin),
      tzId: Value(tzId),
      outcome: Value(outcome),
      interruptionsInternal: Value(interruptionsInternal),
      interruptionsExternal: Value(interruptionsExternal),
      focusRating: focusRating == null && nullToAbsent
          ? const Value.absent()
          : Value(focusRating),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isManual: Value(isManual),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
    );
  }

  factory FocusSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSession(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String?>(json['task_id']),
      projectId: serializer.fromJson<String?>(json['project_id']),
      mode: serializer.fromJson<String>(json['mode']),
      plannedDurationS: serializer.fromJson<int>(json['planned_duration_s']),
      actualDurationS: serializer.fromJson<int>(json['actual_duration_s']),
      startedAt: serializer.fromJson<int>(json['started_at']),
      endedAt: serializer.fromJson<int>(json['ended_at']),
      localDate: serializer.fromJson<String>(json['local_date']),
      tzOffsetMin: serializer.fromJson<int>(json['tz_offset_min']),
      tzId: serializer.fromJson<String>(json['tz_id']),
      outcome: serializer.fromJson<String>(json['outcome']),
      interruptionsInternal: serializer.fromJson<int>(
        json['interruptions_internal'],
      ),
      interruptionsExternal: serializer.fromJson<int>(
        json['interruptions_external'],
      ),
      focusRating: serializer.fromJson<int?>(json['focus_rating']),
      note: serializer.fromJson<String?>(json['note']),
      isManual: serializer.fromJson<bool>(json['is_manual']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'task_id': serializer.toJson<String?>(taskId),
      'project_id': serializer.toJson<String?>(projectId),
      'mode': serializer.toJson<String>(mode),
      'planned_duration_s': serializer.toJson<int>(plannedDurationS),
      'actual_duration_s': serializer.toJson<int>(actualDurationS),
      'started_at': serializer.toJson<int>(startedAt),
      'ended_at': serializer.toJson<int>(endedAt),
      'local_date': serializer.toJson<String>(localDate),
      'tz_offset_min': serializer.toJson<int>(tzOffsetMin),
      'tz_id': serializer.toJson<String>(tzId),
      'outcome': serializer.toJson<String>(outcome),
      'interruptions_internal': serializer.toJson<int>(interruptionsInternal),
      'interruptions_external': serializer.toJson<int>(interruptionsExternal),
      'focus_rating': serializer.toJson<int?>(focusRating),
      'note': serializer.toJson<String?>(note),
      'is_manual': serializer.toJson<bool>(isManual),
      'updated_at': serializer.toJson<int>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  FocusSession copyWith({
    String? id,
    Value<String?> taskId = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
    String? mode,
    int? plannedDurationS,
    int? actualDurationS,
    int? startedAt,
    int? endedAt,
    String? localDate,
    int? tzOffsetMin,
    String? tzId,
    String? outcome,
    int? interruptionsInternal,
    int? interruptionsExternal,
    Value<int?> focusRating = const Value.absent(),
    Value<String?> note = const Value.absent(),
    bool? isManual,
    int? updatedAt,
    String? deviceId,
  }) => FocusSession(
    id: id ?? this.id,
    taskId: taskId.present ? taskId.value : this.taskId,
    projectId: projectId.present ? projectId.value : this.projectId,
    mode: mode ?? this.mode,
    plannedDurationS: plannedDurationS ?? this.plannedDurationS,
    actualDurationS: actualDurationS ?? this.actualDurationS,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    localDate: localDate ?? this.localDate,
    tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
    tzId: tzId ?? this.tzId,
    outcome: outcome ?? this.outcome,
    interruptionsInternal: interruptionsInternal ?? this.interruptionsInternal,
    interruptionsExternal: interruptionsExternal ?? this.interruptionsExternal,
    focusRating: focusRating.present ? focusRating.value : this.focusRating,
    note: note.present ? note.value : this.note,
    isManual: isManual ?? this.isManual,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  FocusSession copyWithCompanion(FocusSessionsCompanion data) {
    return FocusSession(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      mode: data.mode.present ? data.mode.value : this.mode,
      plannedDurationS: data.plannedDurationS.present
          ? data.plannedDurationS.value
          : this.plannedDurationS,
      actualDurationS: data.actualDurationS.present
          ? data.actualDurationS.value
          : this.actualDurationS,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      tzOffsetMin: data.tzOffsetMin.present
          ? data.tzOffsetMin.value
          : this.tzOffsetMin,
      tzId: data.tzId.present ? data.tzId.value : this.tzId,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      interruptionsInternal: data.interruptionsInternal.present
          ? data.interruptionsInternal.value
          : this.interruptionsInternal,
      interruptionsExternal: data.interruptionsExternal.present
          ? data.interruptionsExternal.value
          : this.interruptionsExternal,
      focusRating: data.focusRating.present
          ? data.focusRating.value
          : this.focusRating,
      note: data.note.present ? data.note.value : this.note,
      isManual: data.isManual.present ? data.isManual.value : this.isManual,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSession(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('projectId: $projectId, ')
          ..write('mode: $mode, ')
          ..write('plannedDurationS: $plannedDurationS, ')
          ..write('actualDurationS: $actualDurationS, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('localDate: $localDate, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('tzId: $tzId, ')
          ..write('outcome: $outcome, ')
          ..write('interruptionsInternal: $interruptionsInternal, ')
          ..write('interruptionsExternal: $interruptionsExternal, ')
          ..write('focusRating: $focusRating, ')
          ..write('note: $note, ')
          ..write('isManual: $isManual, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    projectId,
    mode,
    plannedDurationS,
    actualDurationS,
    startedAt,
    endedAt,
    localDate,
    tzOffsetMin,
    tzId,
    outcome,
    interruptionsInternal,
    interruptionsExternal,
    focusRating,
    note,
    isManual,
    updatedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSession &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.projectId == this.projectId &&
          other.mode == this.mode &&
          other.plannedDurationS == this.plannedDurationS &&
          other.actualDurationS == this.actualDurationS &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.localDate == this.localDate &&
          other.tzOffsetMin == this.tzOffsetMin &&
          other.tzId == this.tzId &&
          other.outcome == this.outcome &&
          other.interruptionsInternal == this.interruptionsInternal &&
          other.interruptionsExternal == this.interruptionsExternal &&
          other.focusRating == this.focusRating &&
          other.note == this.note &&
          other.isManual == this.isManual &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId);
}

class FocusSessionsCompanion extends UpdateCompanion<FocusSession> {
  final Value<String> id;
  final Value<String?> taskId;
  final Value<String?> projectId;
  final Value<String> mode;
  final Value<int> plannedDurationS;
  final Value<int> actualDurationS;
  final Value<int> startedAt;
  final Value<int> endedAt;
  final Value<String> localDate;
  final Value<int> tzOffsetMin;
  final Value<String> tzId;
  final Value<String> outcome;
  final Value<int> interruptionsInternal;
  final Value<int> interruptionsExternal;
  final Value<int?> focusRating;
  final Value<String?> note;
  final Value<bool> isManual;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const FocusSessionsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.mode = const Value.absent(),
    this.plannedDurationS = const Value.absent(),
    this.actualDurationS = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.localDate = const Value.absent(),
    this.tzOffsetMin = const Value.absent(),
    this.tzId = const Value.absent(),
    this.outcome = const Value.absent(),
    this.interruptionsInternal = const Value.absent(),
    this.interruptionsExternal = const Value.absent(),
    this.focusRating = const Value.absent(),
    this.note = const Value.absent(),
    this.isManual = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSessionsCompanion.insert({
    required String id,
    this.taskId = const Value.absent(),
    this.projectId = const Value.absent(),
    required String mode,
    this.plannedDurationS = const Value.absent(),
    this.actualDurationS = const Value.absent(),
    required int startedAt,
    required int endedAt,
    required String localDate,
    required int tzOffsetMin,
    this.tzId = const Value.absent(),
    required String outcome,
    this.interruptionsInternal = const Value.absent(),
    this.interruptionsExternal = const Value.absent(),
    this.focusRating = const Value.absent(),
    this.note = const Value.absent(),
    this.isManual = const Value.absent(),
    required int updatedAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mode = Value(mode),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       localDate = Value(localDate),
       tzOffsetMin = Value(tzOffsetMin),
       outcome = Value(outcome),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<FocusSession> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? projectId,
    Expression<String>? mode,
    Expression<int>? plannedDurationS,
    Expression<int>? actualDurationS,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? localDate,
    Expression<int>? tzOffsetMin,
    Expression<String>? tzId,
    Expression<String>? outcome,
    Expression<int>? interruptionsInternal,
    Expression<int>? interruptionsExternal,
    Expression<int>? focusRating,
    Expression<String>? note,
    Expression<bool>? isManual,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (projectId != null) 'project_id': projectId,
      if (mode != null) 'mode': mode,
      if (plannedDurationS != null) 'planned_duration_s': plannedDurationS,
      if (actualDurationS != null) 'actual_duration_s': actualDurationS,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (localDate != null) 'local_date': localDate,
      if (tzOffsetMin != null) 'tz_offset_min': tzOffsetMin,
      if (tzId != null) 'tz_id': tzId,
      if (outcome != null) 'outcome': outcome,
      if (interruptionsInternal != null)
        'interruptions_internal': interruptionsInternal,
      if (interruptionsExternal != null)
        'interruptions_external': interruptionsExternal,
      if (focusRating != null) 'focus_rating': focusRating,
      if (note != null) 'note': note,
      if (isManual != null) 'is_manual': isManual,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? taskId,
    Value<String?>? projectId,
    Value<String>? mode,
    Value<int>? plannedDurationS,
    Value<int>? actualDurationS,
    Value<int>? startedAt,
    Value<int>? endedAt,
    Value<String>? localDate,
    Value<int>? tzOffsetMin,
    Value<String>? tzId,
    Value<String>? outcome,
    Value<int>? interruptionsInternal,
    Value<int>? interruptionsExternal,
    Value<int?>? focusRating,
    Value<String?>? note,
    Value<bool>? isManual,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return FocusSessionsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      projectId: projectId ?? this.projectId,
      mode: mode ?? this.mode,
      plannedDurationS: plannedDurationS ?? this.plannedDurationS,
      actualDurationS: actualDurationS ?? this.actualDurationS,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      localDate: localDate ?? this.localDate,
      tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
      tzId: tzId ?? this.tzId,
      outcome: outcome ?? this.outcome,
      interruptionsInternal:
          interruptionsInternal ?? this.interruptionsInternal,
      interruptionsExternal:
          interruptionsExternal ?? this.interruptionsExternal,
      focusRating: focusRating ?? this.focusRating,
      note: note ?? this.note,
      isManual: isManual ?? this.isManual,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (plannedDurationS.present) {
      map['planned_duration_s'] = Variable<int>(plannedDurationS.value);
    }
    if (actualDurationS.present) {
      map['actual_duration_s'] = Variable<int>(actualDurationS.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (tzOffsetMin.present) {
      map['tz_offset_min'] = Variable<int>(tzOffsetMin.value);
    }
    if (tzId.present) {
      map['tz_id'] = Variable<String>(tzId.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (interruptionsInternal.present) {
      map['interruptions_internal'] = Variable<int>(
        interruptionsInternal.value,
      );
    }
    if (interruptionsExternal.present) {
      map['interruptions_external'] = Variable<int>(
        interruptionsExternal.value,
      );
    }
    if (focusRating.present) {
      map['focus_rating'] = Variable<int>(focusRating.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isManual.present) {
      map['is_manual'] = Variable<bool>(isManual.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('projectId: $projectId, ')
          ..write('mode: $mode, ')
          ..write('plannedDurationS: $plannedDurationS, ')
          ..write('actualDurationS: $actualDurationS, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('localDate: $localDate, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('tzId: $tzId, ')
          ..write('outcome: $outcome, ')
          ..write('interruptionsInternal: $interruptionsInternal, ')
          ..write('interruptionsExternal: $interruptionsExternal, ')
          ..write('focusRating: $focusRating, ')
          ..write('note: $note, ')
          ..write('isManual: $isManual, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<int> dueAt = GeneratedColumn<int>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueIsAllDayMeta = const VerificationMeta(
    'dueIsAllDay',
  );
  @override
  late final GeneratedColumn<bool> dueIsAllDay = GeneratedColumn<bool>(
    'due_is_all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("due_is_all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _estimatePomodorosMeta = const VerificationMeta(
    'estimatePomodoros',
  );
  @override
  late final GeneratedColumn<int> estimatePomodoros = GeneratedColumn<int>(
    'estimate_pomodoros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdLocalDateMeta = const VerificationMeta(
    'createdLocalDate',
  );
  @override
  late final GeneratedColumn<String> createdLocalDate = GeneratedColumn<String>(
    'created_local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedLocalDateMeta =
      const VerificationMeta('completedLocalDate');
  @override
  late final GeneratedColumn<String> completedLocalDate =
      GeneratedColumn<String>(
        'completed_local_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _rescheduleCountMeta = const VerificationMeta(
    'rescheduleCount',
  );
  @override
  late final GeneratedColumn<int> rescheduleCount = GeneratedColumn<int>(
    'reschedule_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _recurrenceRuleMeta = const VerificationMeta(
    'recurrenceRule',
  );
  @override
  late final GeneratedColumn<String> recurrenceRule = GeneratedColumn<String>(
    'recurrence_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceModeMeta = const VerificationMeta(
    'recurrenceMode',
  );
  @override
  late final GeneratedColumn<String> recurrenceMode = GeneratedColumn<String>(
    'recurrence_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceParentIdMeta =
      const VerificationMeta('recurrenceParentId');
  @override
  late final GeneratedColumn<String> recurrenceParentId =
      GeneratedColumn<String>(
        'recurrence_parent_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    notes,
    projectId,
    parentId,
    priority,
    dueAt,
    dueIsAllDay,
    estimatePomodoros,
    status,
    createdAt,
    createdLocalDate,
    completedAt,
    completedLocalDate,
    rescheduleCount,
    recurrenceRule,
    recurrenceMode,
    recurrenceParentId,
    sortOrder,
    updatedAt,
    deviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('due_is_all_day')) {
      context.handle(
        _dueIsAllDayMeta,
        dueIsAllDay.isAcceptableOrUnknown(
          data['due_is_all_day']!,
          _dueIsAllDayMeta,
        ),
      );
    }
    if (data.containsKey('estimate_pomodoros')) {
      context.handle(
        _estimatePomodorosMeta,
        estimatePomodoros.isAcceptableOrUnknown(
          data['estimate_pomodoros']!,
          _estimatePomodorosMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
    if (data.containsKey('created_local_date')) {
      context.handle(
        _createdLocalDateMeta,
        createdLocalDate.isAcceptableOrUnknown(
          data['created_local_date']!,
          _createdLocalDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdLocalDateMeta);
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
    if (data.containsKey('completed_local_date')) {
      context.handle(
        _completedLocalDateMeta,
        completedLocalDate.isAcceptableOrUnknown(
          data['completed_local_date']!,
          _completedLocalDateMeta,
        ),
      );
    }
    if (data.containsKey('reschedule_count')) {
      context.handle(
        _rescheduleCountMeta,
        rescheduleCount.isAcceptableOrUnknown(
          data['reschedule_count']!,
          _rescheduleCountMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_rule')) {
      context.handle(
        _recurrenceRuleMeta,
        recurrenceRule.isAcceptableOrUnknown(
          data['recurrence_rule']!,
          _recurrenceRuleMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_mode')) {
      context.handle(
        _recurrenceModeMeta,
        recurrenceMode.isAcceptableOrUnknown(
          data['recurrence_mode']!,
          _recurrenceModeMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_parent_id')) {
      context.handle(
        _recurrenceParentIdMeta,
        recurrenceParentId.isAcceptableOrUnknown(
          data['recurrence_parent_id']!,
          _recurrenceParentIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
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
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_at'],
      ),
      dueIsAllDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}due_is_all_day'],
      )!,
      estimatePomodoros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimate_pomodoros'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      createdLocalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_local_date'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      completedLocalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_local_date'],
      ),
      rescheduleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reschedule_count'],
      )!,
      recurrenceRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_rule'],
      ),
      recurrenceMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_mode'],
      ),
      recurrenceParentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_parent_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  /// Task identifier (UUID string).
  final String id;

  /// Task title.
  final String title;

  /// Optional notes.
  final String? notes;

  /// Associated project ID, if any.
  final String? projectId;

  /// Parent task ID for subtasks (one level of subtask only).
  final String? parentId;

  /// Priority 1–4 (1 = highest).
  final int priority;

  /// Due instant in UTC epoch milliseconds, if set.
  final int? dueAt;

  /// Whether the due date is all-day (0 = specific time, 1 = all day).
  final bool dueIsAllDay;

  /// Estimated pomodoro count.
  final int? estimatePomodoros;

  /// 'open' | 'done' | 'archived'
  final String status;

  /// Created instant in UTC epoch milliseconds.
  final int createdAt;

  /// Created logical date (YYYY-MM-DD).
  final String createdLocalDate;

  /// Completed instant in UTC epoch milliseconds, null if open.
  final int? completedAt;

  /// Completed logical date (YYYY-MM-DD), null if open.
  final String? completedLocalDate;

  /// Number of times rescheduled to a later date (§4.12).
  final int rescheduleCount;

  /// RRULE subset string.
  final String? recurrenceRule;

  /// 'on_schedule' | 'after_completion' (§2.6).
  final String? recurrenceMode;

  /// Links instances of a recurring series (§2.6).
  final String? recurrenceParentId;

  /// Fractional ordering for drag-and-drop.
  final double sortOrder;

  /// UTC epoch milliseconds, written on every update (§4).
  final int updatedAt;

  /// Which install made the last write (§4, §5).
  final String deviceId;

  /// Tombstone; null means live row, non-null is deletion UTC ms (§4, §6).
  final int? deletedAt;
  const Task({
    required this.id,
    required this.title,
    this.notes,
    this.projectId,
    this.parentId,
    required this.priority,
    this.dueAt,
    required this.dueIsAllDay,
    this.estimatePomodoros,
    required this.status,
    required this.createdAt,
    required this.createdLocalDate,
    this.completedAt,
    this.completedLocalDate,
    required this.rescheduleCount,
    this.recurrenceRule,
    this.recurrenceMode,
    this.recurrenceParentId,
    required this.sortOrder,
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<int>(dueAt);
    }
    map['due_is_all_day'] = Variable<bool>(dueIsAllDay);
    if (!nullToAbsent || estimatePomodoros != null) {
      map['estimate_pomodoros'] = Variable<int>(estimatePomodoros);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    map['created_local_date'] = Variable<String>(createdLocalDate);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || completedLocalDate != null) {
      map['completed_local_date'] = Variable<String>(completedLocalDate);
    }
    map['reschedule_count'] = Variable<int>(rescheduleCount);
    if (!nullToAbsent || recurrenceRule != null) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule);
    }
    if (!nullToAbsent || recurrenceMode != null) {
      map['recurrence_mode'] = Variable<String>(recurrenceMode);
    }
    if (!nullToAbsent || recurrenceParentId != null) {
      map['recurrence_parent_id'] = Variable<String>(recurrenceParentId);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      priority: Value(priority),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      dueIsAllDay: Value(dueIsAllDay),
      estimatePomodoros: estimatePomodoros == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatePomodoros),
      status: Value(status),
      createdAt: Value(createdAt),
      createdLocalDate: Value(createdLocalDate),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      completedLocalDate: completedLocalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(completedLocalDate),
      rescheduleCount: Value(rescheduleCount),
      recurrenceRule: recurrenceRule == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceRule),
      recurrenceMode: recurrenceMode == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceMode),
      recurrenceParentId: recurrenceParentId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceParentId),
      sortOrder: Value(sortOrder),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      projectId: serializer.fromJson<String?>(json['project_id']),
      parentId: serializer.fromJson<String?>(json['parent_id']),
      priority: serializer.fromJson<int>(json['priority']),
      dueAt: serializer.fromJson<int?>(json['due_at']),
      dueIsAllDay: serializer.fromJson<bool>(json['due_is_all_day']),
      estimatePomodoros: serializer.fromJson<int?>(json['estimate_pomodoros']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      createdLocalDate: serializer.fromJson<String>(json['created_local_date']),
      completedAt: serializer.fromJson<int?>(json['completed_at']),
      completedLocalDate: serializer.fromJson<String?>(
        json['completed_local_date'],
      ),
      rescheduleCount: serializer.fromJson<int>(json['reschedule_count']),
      recurrenceRule: serializer.fromJson<String?>(json['recurrence_rule']),
      recurrenceMode: serializer.fromJson<String?>(json['recurrence_mode']),
      recurrenceParentId: serializer.fromJson<String?>(
        json['recurrence_parent_id'],
      ),
      sortOrder: serializer.fromJson<double>(json['sort_order']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'project_id': serializer.toJson<String?>(projectId),
      'parent_id': serializer.toJson<String?>(parentId),
      'priority': serializer.toJson<int>(priority),
      'due_at': serializer.toJson<int?>(dueAt),
      'due_is_all_day': serializer.toJson<bool>(dueIsAllDay),
      'estimate_pomodoros': serializer.toJson<int?>(estimatePomodoros),
      'status': serializer.toJson<String>(status),
      'created_at': serializer.toJson<int>(createdAt),
      'created_local_date': serializer.toJson<String>(createdLocalDate),
      'completed_at': serializer.toJson<int?>(completedAt),
      'completed_local_date': serializer.toJson<String?>(completedLocalDate),
      'reschedule_count': serializer.toJson<int>(rescheduleCount),
      'recurrence_rule': serializer.toJson<String?>(recurrenceRule),
      'recurrence_mode': serializer.toJson<String?>(recurrenceMode),
      'recurrence_parent_id': serializer.toJson<String?>(recurrenceParentId),
      'sort_order': serializer.toJson<double>(sortOrder),
      'updated_at': serializer.toJson<int>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted_at': serializer.toJson<int?>(deletedAt),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    Value<String?> notes = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    int? priority,
    Value<int?> dueAt = const Value.absent(),
    bool? dueIsAllDay,
    Value<int?> estimatePomodoros = const Value.absent(),
    String? status,
    int? createdAt,
    String? createdLocalDate,
    Value<int?> completedAt = const Value.absent(),
    Value<String?> completedLocalDate = const Value.absent(),
    int? rescheduleCount,
    Value<String?> recurrenceRule = const Value.absent(),
    Value<String?> recurrenceMode = const Value.absent(),
    Value<String?> recurrenceParentId = const Value.absent(),
    double? sortOrder,
    int? updatedAt,
    String? deviceId,
    Value<int?> deletedAt = const Value.absent(),
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    projectId: projectId.present ? projectId.value : this.projectId,
    parentId: parentId.present ? parentId.value : this.parentId,
    priority: priority ?? this.priority,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    dueIsAllDay: dueIsAllDay ?? this.dueIsAllDay,
    estimatePomodoros: estimatePomodoros.present
        ? estimatePomodoros.value
        : this.estimatePomodoros,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    createdLocalDate: createdLocalDate ?? this.createdLocalDate,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    completedLocalDate: completedLocalDate.present
        ? completedLocalDate.value
        : this.completedLocalDate,
    rescheduleCount: rescheduleCount ?? this.rescheduleCount,
    recurrenceRule: recurrenceRule.present
        ? recurrenceRule.value
        : this.recurrenceRule,
    recurrenceMode: recurrenceMode.present
        ? recurrenceMode.value
        : this.recurrenceMode,
    recurrenceParentId: recurrenceParentId.present
        ? recurrenceParentId.value
        : this.recurrenceParentId,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      dueIsAllDay: data.dueIsAllDay.present
          ? data.dueIsAllDay.value
          : this.dueIsAllDay,
      estimatePomodoros: data.estimatePomodoros.present
          ? data.estimatePomodoros.value
          : this.estimatePomodoros,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdLocalDate: data.createdLocalDate.present
          ? data.createdLocalDate.value
          : this.createdLocalDate,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      completedLocalDate: data.completedLocalDate.present
          ? data.completedLocalDate.value
          : this.completedLocalDate,
      rescheduleCount: data.rescheduleCount.present
          ? data.rescheduleCount.value
          : this.rescheduleCount,
      recurrenceRule: data.recurrenceRule.present
          ? data.recurrenceRule.value
          : this.recurrenceRule,
      recurrenceMode: data.recurrenceMode.present
          ? data.recurrenceMode.value
          : this.recurrenceMode,
      recurrenceParentId: data.recurrenceParentId.present
          ? data.recurrenceParentId.value
          : this.recurrenceParentId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('projectId: $projectId, ')
          ..write('parentId: $parentId, ')
          ..write('priority: $priority, ')
          ..write('dueAt: $dueAt, ')
          ..write('dueIsAllDay: $dueIsAllDay, ')
          ..write('estimatePomodoros: $estimatePomodoros, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdLocalDate: $createdLocalDate, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedLocalDate: $completedLocalDate, ')
          ..write('rescheduleCount: $rescheduleCount, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceMode: $recurrenceMode, ')
          ..write('recurrenceParentId: $recurrenceParentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    notes,
    projectId,
    parentId,
    priority,
    dueAt,
    dueIsAllDay,
    estimatePomodoros,
    status,
    createdAt,
    createdLocalDate,
    completedAt,
    completedLocalDate,
    rescheduleCount,
    recurrenceRule,
    recurrenceMode,
    recurrenceParentId,
    sortOrder,
    updatedAt,
    deviceId,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.projectId == this.projectId &&
          other.parentId == this.parentId &&
          other.priority == this.priority &&
          other.dueAt == this.dueAt &&
          other.dueIsAllDay == this.dueIsAllDay &&
          other.estimatePomodoros == this.estimatePomodoros &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.createdLocalDate == this.createdLocalDate &&
          other.completedAt == this.completedAt &&
          other.completedLocalDate == this.completedLocalDate &&
          other.rescheduleCount == this.rescheduleCount &&
          other.recurrenceRule == this.recurrenceRule &&
          other.recurrenceMode == this.recurrenceMode &&
          other.recurrenceParentId == this.recurrenceParentId &&
          other.sortOrder == this.sortOrder &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> notes;
  final Value<String?> projectId;
  final Value<String?> parentId;
  final Value<int> priority;
  final Value<int?> dueAt;
  final Value<bool> dueIsAllDay;
  final Value<int?> estimatePomodoros;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<String> createdLocalDate;
  final Value<int?> completedAt;
  final Value<String?> completedLocalDate;
  final Value<int> rescheduleCount;
  final Value<String?> recurrenceRule;
  final Value<String?> recurrenceMode;
  final Value<String?> recurrenceParentId;
  final Value<double> sortOrder;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.projectId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.dueIsAllDay = const Value.absent(),
    this.estimatePomodoros = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdLocalDate = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completedLocalDate = const Value.absent(),
    this.rescheduleCount = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceMode = const Value.absent(),
    this.recurrenceParentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String title,
    this.notes = const Value.absent(),
    this.projectId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.dueIsAllDay = const Value.absent(),
    this.estimatePomodoros = const Value.absent(),
    this.status = const Value.absent(),
    required int createdAt,
    required String createdLocalDate,
    this.completedAt = const Value.absent(),
    this.completedLocalDate = const Value.absent(),
    this.rescheduleCount = const Value.absent(),
    this.recurrenceRule = const Value.absent(),
    this.recurrenceMode = const Value.absent(),
    this.recurrenceParentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int updatedAt,
    required String deviceId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       createdLocalDate = Value(createdLocalDate),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<String>? projectId,
    Expression<String>? parentId,
    Expression<int>? priority,
    Expression<int>? dueAt,
    Expression<bool>? dueIsAllDay,
    Expression<int>? estimatePomodoros,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<String>? createdLocalDate,
    Expression<int>? completedAt,
    Expression<String>? completedLocalDate,
    Expression<int>? rescheduleCount,
    Expression<String>? recurrenceRule,
    Expression<String>? recurrenceMode,
    Expression<String>? recurrenceParentId,
    Expression<double>? sortOrder,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (projectId != null) 'project_id': projectId,
      if (parentId != null) 'parent_id': parentId,
      if (priority != null) 'priority': priority,
      if (dueAt != null) 'due_at': dueAt,
      if (dueIsAllDay != null) 'due_is_all_day': dueIsAllDay,
      if (estimatePomodoros != null) 'estimate_pomodoros': estimatePomodoros,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (createdLocalDate != null) 'created_local_date': createdLocalDate,
      if (completedAt != null) 'completed_at': completedAt,
      if (completedLocalDate != null)
        'completed_local_date': completedLocalDate,
      if (rescheduleCount != null) 'reschedule_count': rescheduleCount,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (recurrenceMode != null) 'recurrence_mode': recurrenceMode,
      if (recurrenceParentId != null)
        'recurrence_parent_id': recurrenceParentId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? notes,
    Value<String?>? projectId,
    Value<String?>? parentId,
    Value<int>? priority,
    Value<int?>? dueAt,
    Value<bool>? dueIsAllDay,
    Value<int?>? estimatePomodoros,
    Value<String>? status,
    Value<int>? createdAt,
    Value<String>? createdLocalDate,
    Value<int?>? completedAt,
    Value<String?>? completedLocalDate,
    Value<int>? rescheduleCount,
    Value<String?>? recurrenceRule,
    Value<String?>? recurrenceMode,
    Value<String?>? recurrenceParentId,
    Value<double>? sortOrder,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      projectId: projectId ?? this.projectId,
      parentId: parentId ?? this.parentId,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      dueIsAllDay: dueIsAllDay ?? this.dueIsAllDay,
      estimatePomodoros: estimatePomodoros ?? this.estimatePomodoros,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdLocalDate: createdLocalDate ?? this.createdLocalDate,
      completedAt: completedAt ?? this.completedAt,
      completedLocalDate: completedLocalDate ?? this.completedLocalDate,
      rescheduleCount: rescheduleCount ?? this.rescheduleCount,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceMode: recurrenceMode ?? this.recurrenceMode,
      recurrenceParentId: recurrenceParentId ?? this.recurrenceParentId,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<int>(dueAt.value);
    }
    if (dueIsAllDay.present) {
      map['due_is_all_day'] = Variable<bool>(dueIsAllDay.value);
    }
    if (estimatePomodoros.present) {
      map['estimate_pomodoros'] = Variable<int>(estimatePomodoros.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (createdLocalDate.present) {
      map['created_local_date'] = Variable<String>(createdLocalDate.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (completedLocalDate.present) {
      map['completed_local_date'] = Variable<String>(completedLocalDate.value);
    }
    if (rescheduleCount.present) {
      map['reschedule_count'] = Variable<int>(rescheduleCount.value);
    }
    if (recurrenceRule.present) {
      map['recurrence_rule'] = Variable<String>(recurrenceRule.value);
    }
    if (recurrenceMode.present) {
      map['recurrence_mode'] = Variable<String>(recurrenceMode.value);
    }
    if (recurrenceParentId.present) {
      map['recurrence_parent_id'] = Variable<String>(recurrenceParentId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('projectId: $projectId, ')
          ..write('parentId: $parentId, ')
          ..write('priority: $priority, ')
          ..write('dueAt: $dueAt, ')
          ..write('dueIsAllDay: $dueIsAllDay, ')
          ..write('estimatePomodoros: $estimatePomodoros, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdLocalDate: $createdLocalDate, ')
          ..write('completedAt: $completedAt, ')
          ..write('completedLocalDate: $completedLocalDate, ')
          ..write('rescheduleCount: $rescheduleCount, ')
          ..write('recurrenceRule: $recurrenceRule, ')
          ..write('recurrenceMode: $recurrenceMode, ')
          ..write('recurrenceParentId: $recurrenceParentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskReminderOffsetsTable extends TaskReminderOffsets
    with TableInfo<$TaskReminderOffsetsTable, TaskReminderOffset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskReminderOffsetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offsetMinMeta = const VerificationMeta(
    'offsetMin',
  );
  @override
  late final GeneratedColumn<int> offsetMin = GeneratedColumn<int>(
    'offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    offsetMin,
    notificationId,
    createdAt,
    updatedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_reminder_offsets';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskReminderOffset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('offset_min')) {
      context.handle(
        _offsetMinMeta,
        offsetMin.isAcceptableOrUnknown(data['offset_min']!, _offsetMinMeta),
      );
    } else if (isInserting) {
      context.missing(_offsetMinMeta);
    }
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
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
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {taskId, offsetMin},
  ];
  @override
  TaskReminderOffset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskReminderOffset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      offsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_min'],
      )!,
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $TaskReminderOffsetsTable createAlias(String alias) {
    return $TaskReminderOffsetsTable(attachedDatabase, alias);
  }
}

class TaskReminderOffset extends DataClass
    implements Insertable<TaskReminderOffset> {
  /// Row identifier (UUIDv7 string).
  final String id;

  /// The task this reminder belongs to.
  final String taskId;

  /// Minutes before `tasks.due_at` to fire. 0 means "at the due time".
  final int offsetMin;

  /// Stable 32-bit id for this row's scheduled OS notification, allocated
  /// from the same counter as every other notification id in the app (see
  /// `tasks.dart` for why hashing is not used instead). Null until
  /// `ReminderService` first schedules it.
  final int? notificationId;

  /// Created instant in UTC epoch milliseconds.
  final int createdAt;

  /// UTC epoch milliseconds, written whenever the row is (re)created.
  final int updatedAt;

  /// Which install made the last write.
  final String deviceId;
  const TaskReminderOffset({
    required this.id,
    required this.taskId,
    required this.offsetMin,
    this.notificationId,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['offset_min'] = Variable<int>(offsetMin);
    if (!nullToAbsent || notificationId != null) {
      map['notification_id'] = Variable<int>(notificationId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  TaskReminderOffsetsCompanion toCompanion(bool nullToAbsent) {
    return TaskReminderOffsetsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      offsetMin: Value(offsetMin),
      notificationId: notificationId == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
    );
  }

  factory TaskReminderOffset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskReminderOffset(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['task_id']),
      offsetMin: serializer.fromJson<int>(json['offset_min']),
      notificationId: serializer.fromJson<int?>(json['notification_id']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'task_id': serializer.toJson<String>(taskId),
      'offset_min': serializer.toJson<int>(offsetMin),
      'notification_id': serializer.toJson<int?>(notificationId),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  TaskReminderOffset copyWith({
    String? id,
    String? taskId,
    int? offsetMin,
    Value<int?> notificationId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    String? deviceId,
  }) => TaskReminderOffset(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    offsetMin: offsetMin ?? this.offsetMin,
    notificationId: notificationId.present
        ? notificationId.value
        : this.notificationId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  TaskReminderOffset copyWithCompanion(TaskReminderOffsetsCompanion data) {
    return TaskReminderOffset(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      offsetMin: data.offsetMin.present ? data.offsetMin.value : this.offsetMin,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskReminderOffset(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('offsetMin: $offsetMin, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    offsetMin,
    notificationId,
    createdAt,
    updatedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskReminderOffset &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.offsetMin == this.offsetMin &&
          other.notificationId == this.notificationId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId);
}

class TaskReminderOffsetsCompanion extends UpdateCompanion<TaskReminderOffset> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<int> offsetMin;
  final Value<int?> notificationId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const TaskReminderOffsetsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.offsetMin = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskReminderOffsetsCompanion.insert({
    required String id,
    required String taskId,
    required int offsetMin,
    this.notificationId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       offsetMin = Value(offsetMin),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<TaskReminderOffset> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<int>? offsetMin,
    Expression<int>? notificationId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (offsetMin != null) 'offset_min': offsetMin,
      if (notificationId != null) 'notification_id': notificationId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskReminderOffsetsCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<int>? offsetMin,
    Value<int?>? notificationId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return TaskReminderOffsetsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      offsetMin: offsetMin ?? this.offsetMin,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (offsetMin.present) {
      map['offset_min'] = Variable<int>(offsetMin.value);
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskReminderOffsetsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('offsetMin: $offsetMin, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitsTable extends Habits with TableInfo<$HabitsTable, Habit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('check'),
  );
  static const VerificationMeta _scheduleRuleMeta = const VerificationMeta(
    'scheduleRule',
  );
  @override
  late final GeneratedColumn<String> scheduleRule = GeneratedColumn<String>(
    'schedule_rule',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _anchorDateMeta = const VerificationMeta(
    'anchorDate',
  );
  @override
  late final GeneratedColumn<String> anchorDate = GeneratedColumn<String>(
    'anchor_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetCountMeta = const VerificationMeta(
    'targetCount',
  );
  @override
  late final GeneratedColumn<int> targetCount = GeneratedColumn<int>(
    'target_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _unitLabelMeta = const VerificationMeta(
    'unitLabel',
  );
  @override
  late final GeneratedColumn<String> unitLabel = GeneratedColumn<String>(
    'unit_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _skipAllowancePerMonthMeta =
      const VerificationMeta('skipAllowancePerMonth');
  @override
  late final GeneratedColumn<int> skipAllowancePerMonth = GeneratedColumn<int>(
    'skip_allowance_per_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdLocalDateMeta = const VerificationMeta(
    'createdLocalDate',
  );
  @override
  late final GeneratedColumn<String> createdLocalDate = GeneratedColumn<String>(
    'created_local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    notes,
    colorIndex,
    iconName,
    scheduleRule,
    anchorDate,
    targetCount,
    unitLabel,
    skipAllowancePerMonth,
    status,
    sortOrder,
    createdAt,
    createdLocalDate,
    archivedAt,
    updatedAt,
    deviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habits';
  @override
  VerificationContext validateIntegrity(
    Insertable<Habit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    }
    if (data.containsKey('schedule_rule')) {
      context.handle(
        _scheduleRuleMeta,
        scheduleRule.isAcceptableOrUnknown(
          data['schedule_rule']!,
          _scheduleRuleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleRuleMeta);
    }
    if (data.containsKey('anchor_date')) {
      context.handle(
        _anchorDateMeta,
        anchorDate.isAcceptableOrUnknown(data['anchor_date']!, _anchorDateMeta),
      );
    } else if (isInserting) {
      context.missing(_anchorDateMeta);
    }
    if (data.containsKey('target_count')) {
      context.handle(
        _targetCountMeta,
        targetCount.isAcceptableOrUnknown(
          data['target_count']!,
          _targetCountMeta,
        ),
      );
    }
    if (data.containsKey('unit_label')) {
      context.handle(
        _unitLabelMeta,
        unitLabel.isAcceptableOrUnknown(data['unit_label']!, _unitLabelMeta),
      );
    }
    if (data.containsKey('skip_allowance_per_month')) {
      context.handle(
        _skipAllowancePerMonthMeta,
        skipAllowancePerMonth.isAcceptableOrUnknown(
          data['skip_allowance_per_month']!,
          _skipAllowancePerMonthMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    if (data.containsKey('created_local_date')) {
      context.handle(
        _createdLocalDateMeta,
        createdLocalDate.isAcceptableOrUnknown(
          data['created_local_date']!,
          _createdLocalDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdLocalDateMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
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
  Habit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Habit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      )!,
      scheduleRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_rule'],
      )!,
      anchorDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anchor_date'],
      )!,
      targetCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_count'],
      )!,
      unitLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_label'],
      ),
      skipAllowancePerMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skip_allowance_per_month'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      createdLocalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_local_date'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $HabitsTable createAlias(String alias) {
    return $HabitsTable(attachedDatabase, alias);
  }
}

class Habit extends DataClass implements Insertable<Habit> {
  /// Habit identifier (UUIDv7 string).
  final String id;

  /// What the user calls it. "Read", "Walk the dog", "No sugar".
  final String title;

  /// Optional longer description shown on the detail screen.
  final String? notes;

  /// Index into the theme's habit palette.
  final int colorIndex;

  /// Icon identifier, resolved to an [IconData] by the presentation layer.
  /// Stored as a name, not a code point: Flutter's icon code points are not
  /// stable across versions, and a backup restored after an upgrade would
  /// otherwise show a grid of random glyphs.
  final String iconName;

  /// RRULE subset (SPEC.md §2.6), the same grammar task recurrence uses.
  /// Non-null: a habit with no schedule is never due, which is not a habit.
  final String scheduleRule;

  /// The logical date intervals count from — normally the day it was created.
  ///
  /// "Every 3 days" means every third day from here, so this must be stored
  /// rather than recomputed. Deriving it from created_at would silently
  /// reschedule the whole history if a row were ever backfilled.
  final String anchorDate;

  /// How many check-offs make a day complete. 1 for a plain yes/no habit.
  final int targetCount;

  /// What the target is counted in — "pages", "glasses". Null for yes/no.
  final String? unitLabel;

  /// Rest days a calendar month excuses without breaking the streak (§10.3).
  final int skipAllowancePerMonth;

  /// 'active' | 'archived'
  final String status;

  /// Fractional ordering for drag-and-drop.
  final double sortOrder;

  /// Created instant in UTC epoch milliseconds.
  final int createdAt;

  /// Created logical date (YYYY-MM-DD).
  final String createdLocalDate;

  /// Archived instant in UTC epoch milliseconds, null while active.
  final int? archivedAt;

  /// UTC epoch milliseconds, written on every update.
  final int updatedAt;

  /// Which install made the last write.
  final String deviceId;

  /// Tombstone; null means live row, non-null is deletion UTC ms.
  final int? deletedAt;
  const Habit({
    required this.id,
    required this.title,
    this.notes,
    required this.colorIndex,
    required this.iconName,
    required this.scheduleRule,
    required this.anchorDate,
    required this.targetCount,
    this.unitLabel,
    required this.skipAllowancePerMonth,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    required this.createdLocalDate,
    this.archivedAt,
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['color_index'] = Variable<int>(colorIndex);
    map['icon_name'] = Variable<String>(iconName);
    map['schedule_rule'] = Variable<String>(scheduleRule);
    map['anchor_date'] = Variable<String>(anchorDate);
    map['target_count'] = Variable<int>(targetCount);
    if (!nullToAbsent || unitLabel != null) {
      map['unit_label'] = Variable<String>(unitLabel);
    }
    map['skip_allowance_per_month'] = Variable<int>(skipAllowancePerMonth);
    map['status'] = Variable<String>(status);
    map['sort_order'] = Variable<double>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['created_local_date'] = Variable<String>(createdLocalDate);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  HabitsCompanion toCompanion(bool nullToAbsent) {
    return HabitsCompanion(
      id: Value(id),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      colorIndex: Value(colorIndex),
      iconName: Value(iconName),
      scheduleRule: Value(scheduleRule),
      anchorDate: Value(anchorDate),
      targetCount: Value(targetCount),
      unitLabel: unitLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(unitLabel),
      skipAllowancePerMonth: Value(skipAllowancePerMonth),
      status: Value(status),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      createdLocalDate: Value(createdLocalDate),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Habit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Habit(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      colorIndex: serializer.fromJson<int>(json['color_index']),
      iconName: serializer.fromJson<String>(json['icon_name']),
      scheduleRule: serializer.fromJson<String>(json['schedule_rule']),
      anchorDate: serializer.fromJson<String>(json['anchor_date']),
      targetCount: serializer.fromJson<int>(json['target_count']),
      unitLabel: serializer.fromJson<String?>(json['unit_label']),
      skipAllowancePerMonth: serializer.fromJson<int>(
        json['skip_allowance_per_month'],
      ),
      status: serializer.fromJson<String>(json['status']),
      sortOrder: serializer.fromJson<double>(json['sort_order']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      createdLocalDate: serializer.fromJson<String>(json['created_local_date']),
      archivedAt: serializer.fromJson<int?>(json['archived_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'color_index': serializer.toJson<int>(colorIndex),
      'icon_name': serializer.toJson<String>(iconName),
      'schedule_rule': serializer.toJson<String>(scheduleRule),
      'anchor_date': serializer.toJson<String>(anchorDate),
      'target_count': serializer.toJson<int>(targetCount),
      'unit_label': serializer.toJson<String?>(unitLabel),
      'skip_allowance_per_month': serializer.toJson<int>(skipAllowancePerMonth),
      'status': serializer.toJson<String>(status),
      'sort_order': serializer.toJson<double>(sortOrder),
      'created_at': serializer.toJson<int>(createdAt),
      'created_local_date': serializer.toJson<String>(createdLocalDate),
      'archived_at': serializer.toJson<int?>(archivedAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted_at': serializer.toJson<int?>(deletedAt),
    };
  }

  Habit copyWith({
    String? id,
    String? title,
    Value<String?> notes = const Value.absent(),
    int? colorIndex,
    String? iconName,
    String? scheduleRule,
    String? anchorDate,
    int? targetCount,
    Value<String?> unitLabel = const Value.absent(),
    int? skipAllowancePerMonth,
    String? status,
    double? sortOrder,
    int? createdAt,
    String? createdLocalDate,
    Value<int?> archivedAt = const Value.absent(),
    int? updatedAt,
    String? deviceId,
    Value<int?> deletedAt = const Value.absent(),
  }) => Habit(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    colorIndex: colorIndex ?? this.colorIndex,
    iconName: iconName ?? this.iconName,
    scheduleRule: scheduleRule ?? this.scheduleRule,
    anchorDate: anchorDate ?? this.anchorDate,
    targetCount: targetCount ?? this.targetCount,
    unitLabel: unitLabel.present ? unitLabel.value : this.unitLabel,
    skipAllowancePerMonth: skipAllowancePerMonth ?? this.skipAllowancePerMonth,
    status: status ?? this.status,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    createdLocalDate: createdLocalDate ?? this.createdLocalDate,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Habit copyWithCompanion(HabitsCompanion data) {
    return Habit(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      scheduleRule: data.scheduleRule.present
          ? data.scheduleRule.value
          : this.scheduleRule,
      anchorDate: data.anchorDate.present
          ? data.anchorDate.value
          : this.anchorDate,
      targetCount: data.targetCount.present
          ? data.targetCount.value
          : this.targetCount,
      unitLabel: data.unitLabel.present ? data.unitLabel.value : this.unitLabel,
      skipAllowancePerMonth: data.skipAllowancePerMonth.present
          ? data.skipAllowancePerMonth.value
          : this.skipAllowancePerMonth,
      status: data.status.present ? data.status.value : this.status,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdLocalDate: data.createdLocalDate.present
          ? data.createdLocalDate.value
          : this.createdLocalDate,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Habit(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('iconName: $iconName, ')
          ..write('scheduleRule: $scheduleRule, ')
          ..write('anchorDate: $anchorDate, ')
          ..write('targetCount: $targetCount, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('skipAllowancePerMonth: $skipAllowancePerMonth, ')
          ..write('status: $status, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdLocalDate: $createdLocalDate, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    colorIndex,
    iconName,
    scheduleRule,
    anchorDate,
    targetCount,
    unitLabel,
    skipAllowancePerMonth,
    status,
    sortOrder,
    createdAt,
    createdLocalDate,
    archivedAt,
    updatedAt,
    deviceId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Habit &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.colorIndex == this.colorIndex &&
          other.iconName == this.iconName &&
          other.scheduleRule == this.scheduleRule &&
          other.anchorDate == this.anchorDate &&
          other.targetCount == this.targetCount &&
          other.unitLabel == this.unitLabel &&
          other.skipAllowancePerMonth == this.skipAllowancePerMonth &&
          other.status == this.status &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.createdLocalDate == this.createdLocalDate &&
          other.archivedAt == this.archivedAt &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt);
}

class HabitsCompanion extends UpdateCompanion<Habit> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> notes;
  final Value<int> colorIndex;
  final Value<String> iconName;
  final Value<String> scheduleRule;
  final Value<String> anchorDate;
  final Value<int> targetCount;
  final Value<String?> unitLabel;
  final Value<int> skipAllowancePerMonth;
  final Value<String> status;
  final Value<double> sortOrder;
  final Value<int> createdAt;
  final Value<String> createdLocalDate;
  final Value<int?> archivedAt;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const HabitsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.iconName = const Value.absent(),
    this.scheduleRule = const Value.absent(),
    this.anchorDate = const Value.absent(),
    this.targetCount = const Value.absent(),
    this.unitLabel = const Value.absent(),
    this.skipAllowancePerMonth = const Value.absent(),
    this.status = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdLocalDate = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitsCompanion.insert({
    required String id,
    required String title,
    this.notes = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.iconName = const Value.absent(),
    required String scheduleRule,
    required String anchorDate,
    this.targetCount = const Value.absent(),
    this.unitLabel = const Value.absent(),
    this.skipAllowancePerMonth = const Value.absent(),
    this.status = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required String createdLocalDate,
    this.archivedAt = const Value.absent(),
    required int updatedAt,
    required String deviceId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       scheduleRule = Value(scheduleRule),
       anchorDate = Value(anchorDate),
       createdAt = Value(createdAt),
       createdLocalDate = Value(createdLocalDate),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<Habit> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? colorIndex,
    Expression<String>? iconName,
    Expression<String>? scheduleRule,
    Expression<String>? anchorDate,
    Expression<int>? targetCount,
    Expression<String>? unitLabel,
    Expression<int>? skipAllowancePerMonth,
    Expression<String>? status,
    Expression<double>? sortOrder,
    Expression<int>? createdAt,
    Expression<String>? createdLocalDate,
    Expression<int>? archivedAt,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (colorIndex != null) 'color_index': colorIndex,
      if (iconName != null) 'icon_name': iconName,
      if (scheduleRule != null) 'schedule_rule': scheduleRule,
      if (anchorDate != null) 'anchor_date': anchorDate,
      if (targetCount != null) 'target_count': targetCount,
      if (unitLabel != null) 'unit_label': unitLabel,
      if (skipAllowancePerMonth != null)
        'skip_allowance_per_month': skipAllowancePerMonth,
      if (status != null) 'status': status,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (createdLocalDate != null) 'created_local_date': createdLocalDate,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? notes,
    Value<int>? colorIndex,
    Value<String>? iconName,
    Value<String>? scheduleRule,
    Value<String>? anchorDate,
    Value<int>? targetCount,
    Value<String?>? unitLabel,
    Value<int>? skipAllowancePerMonth,
    Value<String>? status,
    Value<double>? sortOrder,
    Value<int>? createdAt,
    Value<String>? createdLocalDate,
    Value<int?>? archivedAt,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return HabitsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      colorIndex: colorIndex ?? this.colorIndex,
      iconName: iconName ?? this.iconName,
      scheduleRule: scheduleRule ?? this.scheduleRule,
      anchorDate: anchorDate ?? this.anchorDate,
      targetCount: targetCount ?? this.targetCount,
      unitLabel: unitLabel ?? this.unitLabel,
      skipAllowancePerMonth:
          skipAllowancePerMonth ?? this.skipAllowancePerMonth,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      createdLocalDate: createdLocalDate ?? this.createdLocalDate,
      archivedAt: archivedAt ?? this.archivedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (scheduleRule.present) {
      map['schedule_rule'] = Variable<String>(scheduleRule.value);
    }
    if (anchorDate.present) {
      map['anchor_date'] = Variable<String>(anchorDate.value);
    }
    if (targetCount.present) {
      map['target_count'] = Variable<int>(targetCount.value);
    }
    if (unitLabel.present) {
      map['unit_label'] = Variable<String>(unitLabel.value);
    }
    if (skipAllowancePerMonth.present) {
      map['skip_allowance_per_month'] = Variable<int>(
        skipAllowancePerMonth.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (createdLocalDate.present) {
      map['created_local_date'] = Variable<String>(createdLocalDate.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('iconName: $iconName, ')
          ..write('scheduleRule: $scheduleRule, ')
          ..write('anchorDate: $anchorDate, ')
          ..write('targetCount: $targetCount, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('skipAllowancePerMonth: $skipAllowancePerMonth, ')
          ..write('status: $status, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdLocalDate: $createdLocalDate, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitEntriesTable extends HabitEntries
    with TableInfo<$HabitEntriesTable, HabitEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkCountMeta = const VerificationMeta(
    'checkCount',
  );
  @override
  late final GeneratedColumn<int> checkCount = GeneratedColumn<int>(
    'check_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skippedMeta = const VerificationMeta(
    'skipped',
  );
  @override
  late final GeneratedColumn<bool> skipped = GeneratedColumn<bool>(
    'skipped',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("skipped" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCheckedAtMeta = const VerificationMeta(
    'lastCheckedAt',
  );
  @override
  late final GeneratedColumn<int> lastCheckedAt = GeneratedColumn<int>(
    'last_checked_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tzOffsetMinMeta = const VerificationMeta(
    'tzOffsetMin',
  );
  @override
  late final GeneratedColumn<int> tzOffsetMin = GeneratedColumn<int>(
    'tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    localDate,
    checkCount,
    skipped,
    note,
    lastCheckedAt,
    tzOffsetMin,
    createdAt,
    updatedAt,
    deviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('check_count')) {
      context.handle(
        _checkCountMeta,
        checkCount.isAcceptableOrUnknown(data['check_count']!, _checkCountMeta),
      );
    }
    if (data.containsKey('skipped')) {
      context.handle(
        _skippedMeta,
        skipped.isAcceptableOrUnknown(data['skipped']!, _skippedMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('last_checked_at')) {
      context.handle(
        _lastCheckedAtMeta,
        lastCheckedAt.isAcceptableOrUnknown(
          data['last_checked_at']!,
          _lastCheckedAtMeta,
        ),
      );
    }
    if (data.containsKey('tz_offset_min')) {
      context.handle(
        _tzOffsetMinMeta,
        tzOffsetMin.isAcceptableOrUnknown(
          data['tz_offset_min']!,
          _tzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMinMeta);
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
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
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
    {habitId, localDate},
  ];
  @override
  HabitEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      checkCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}check_count'],
      )!,
      skipped: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}skipped'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      lastCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_checked_at'],
      ),
      tzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset_min'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $HabitEntriesTable createAlias(String alias) {
    return $HabitEntriesTable(attachedDatabase, alias);
  }
}

class HabitEntry extends DataClass implements Insertable<HabitEntry> {
  /// Entry identifier (UUIDv7 string).
  final String id;

  /// The habit this belongs to.
  final String habitId;

  /// Logical date (YYYY-MM-DD) per SPEC.md §1.2, computed once at write time.
  ///
  /// Computed at write time, never at read time, so a check-off made at 02:00
  /// with a 04:00 day start stays on the day the user believes they did it —
  /// including after they fly somewhere else.
  final String localDate;

  /// How many times it was checked off that day. Compared against
  /// `habits.target_count` to decide whether the day is complete.
  final int checkCount;

  /// The user deliberately marked this a rest day.
  ///
  /// Distinct from a miss, and distinct from being excused: whether the skip
  /// protects the streak depends on the month's remaining allowance, which the
  /// streak engine resolves. This column records only what the user did.
  final bool skipped;

  /// Optional note for the day — the journal entry.
  final String? note;

  /// UTC ms of the most recent check-off, for "done at 7:14am".
  final int? lastCheckedAt;

  /// Offset in minutes at write time, so a day grid can be rendered in the
  /// zone the check-off actually happened in rather than the current device's.
  final int tzOffsetMin;

  /// Created instant in UTC epoch milliseconds.
  final int createdAt;

  /// UTC epoch milliseconds, written on every update.
  final int updatedAt;

  /// Which install made the last write.
  final String deviceId;

  /// Tombstone; null means live row, non-null is deletion UTC ms.
  final int? deletedAt;
  const HabitEntry({
    required this.id,
    required this.habitId,
    required this.localDate,
    required this.checkCount,
    required this.skipped,
    this.note,
    this.lastCheckedAt,
    required this.tzOffsetMin,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['local_date'] = Variable<String>(localDate);
    map['check_count'] = Variable<int>(checkCount);
    map['skipped'] = Variable<bool>(skipped);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || lastCheckedAt != null) {
      map['last_checked_at'] = Variable<int>(lastCheckedAt);
    }
    map['tz_offset_min'] = Variable<int>(tzOffsetMin);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  HabitEntriesCompanion toCompanion(bool nullToAbsent) {
    return HabitEntriesCompanion(
      id: Value(id),
      habitId: Value(habitId),
      localDate: Value(localDate),
      checkCount: Value(checkCount),
      skipped: Value(skipped),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      lastCheckedAt: lastCheckedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckedAt),
      tzOffsetMin: Value(tzOffsetMin),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory HabitEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitEntry(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String>(json['habit_id']),
      localDate: serializer.fromJson<String>(json['local_date']),
      checkCount: serializer.fromJson<int>(json['check_count']),
      skipped: serializer.fromJson<bool>(json['skipped']),
      note: serializer.fromJson<String?>(json['note']),
      lastCheckedAt: serializer.fromJson<int?>(json['last_checked_at']),
      tzOffsetMin: serializer.fromJson<int>(json['tz_offset_min']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habit_id': serializer.toJson<String>(habitId),
      'local_date': serializer.toJson<String>(localDate),
      'check_count': serializer.toJson<int>(checkCount),
      'skipped': serializer.toJson<bool>(skipped),
      'note': serializer.toJson<String?>(note),
      'last_checked_at': serializer.toJson<int?>(lastCheckedAt),
      'tz_offset_min': serializer.toJson<int>(tzOffsetMin),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted_at': serializer.toJson<int?>(deletedAt),
    };
  }

  HabitEntry copyWith({
    String? id,
    String? habitId,
    String? localDate,
    int? checkCount,
    bool? skipped,
    Value<String?> note = const Value.absent(),
    Value<int?> lastCheckedAt = const Value.absent(),
    int? tzOffsetMin,
    int? createdAt,
    int? updatedAt,
    String? deviceId,
    Value<int?> deletedAt = const Value.absent(),
  }) => HabitEntry(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    localDate: localDate ?? this.localDate,
    checkCount: checkCount ?? this.checkCount,
    skipped: skipped ?? this.skipped,
    note: note.present ? note.value : this.note,
    lastCheckedAt: lastCheckedAt.present
        ? lastCheckedAt.value
        : this.lastCheckedAt,
    tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  HabitEntry copyWithCompanion(HabitEntriesCompanion data) {
    return HabitEntry(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      checkCount: data.checkCount.present
          ? data.checkCount.value
          : this.checkCount,
      skipped: data.skipped.present ? data.skipped.value : this.skipped,
      note: data.note.present ? data.note.value : this.note,
      lastCheckedAt: data.lastCheckedAt.present
          ? data.lastCheckedAt.value
          : this.lastCheckedAt,
      tzOffsetMin: data.tzOffsetMin.present
          ? data.tzOffsetMin.value
          : this.tzOffsetMin,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitEntry(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('localDate: $localDate, ')
          ..write('checkCount: $checkCount, ')
          ..write('skipped: $skipped, ')
          ..write('note: $note, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    localDate,
    checkCount,
    skipped,
    note,
    lastCheckedAt,
    tzOffsetMin,
    createdAt,
    updatedAt,
    deviceId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitEntry &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.localDate == this.localDate &&
          other.checkCount == this.checkCount &&
          other.skipped == this.skipped &&
          other.note == this.note &&
          other.lastCheckedAt == this.lastCheckedAt &&
          other.tzOffsetMin == this.tzOffsetMin &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt);
}

class HabitEntriesCompanion extends UpdateCompanion<HabitEntry> {
  final Value<String> id;
  final Value<String> habitId;
  final Value<String> localDate;
  final Value<int> checkCount;
  final Value<bool> skipped;
  final Value<String?> note;
  final Value<int?> lastCheckedAt;
  final Value<int> tzOffsetMin;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const HabitEntriesCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.localDate = const Value.absent(),
    this.checkCount = const Value.absent(),
    this.skipped = const Value.absent(),
    this.note = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.tzOffsetMin = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitEntriesCompanion.insert({
    required String id,
    required String habitId,
    required String localDate,
    this.checkCount = const Value.absent(),
    this.skipped = const Value.absent(),
    this.note = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    required int tzOffsetMin,
    required int createdAt,
    required int updatedAt,
    required String deviceId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       habitId = Value(habitId),
       localDate = Value(localDate),
       tzOffsetMin = Value(tzOffsetMin),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<HabitEntry> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<String>? localDate,
    Expression<int>? checkCount,
    Expression<bool>? skipped,
    Expression<String>? note,
    Expression<int>? lastCheckedAt,
    Expression<int>? tzOffsetMin,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (localDate != null) 'local_date': localDate,
      if (checkCount != null) 'check_count': checkCount,
      if (skipped != null) 'skipped': skipped,
      if (note != null) 'note': note,
      if (lastCheckedAt != null) 'last_checked_at': lastCheckedAt,
      if (tzOffsetMin != null) 'tz_offset_min': tzOffsetMin,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? habitId,
    Value<String>? localDate,
    Value<int>? checkCount,
    Value<bool>? skipped,
    Value<String?>? note,
    Value<int?>? lastCheckedAt,
    Value<int>? tzOffsetMin,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return HabitEntriesCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      localDate: localDate ?? this.localDate,
      checkCount: checkCount ?? this.checkCount,
      skipped: skipped ?? this.skipped,
      note: note ?? this.note,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (checkCount.present) {
      map['check_count'] = Variable<int>(checkCount.value);
    }
    if (skipped.present) {
      map['skipped'] = Variable<bool>(skipped.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (lastCheckedAt.present) {
      map['last_checked_at'] = Variable<int>(lastCheckedAt.value);
    }
    if (tzOffsetMin.present) {
      map['tz_offset_min'] = Variable<int>(tzOffsetMin.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitEntriesCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('localDate: $localDate, ')
          ..write('checkCount: $checkCount, ')
          ..write('skipped: $skipped, ')
          ..write('note: $note, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitReminderTimesTable extends HabitReminderTimes
    with TableInfo<$HabitReminderTimesTable, HabitReminderTime> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitReminderTimesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minutesPastMidnightMeta =
      const VerificationMeta('minutesPastMidnight');
  @override
  late final GeneratedColumn<int> minutesPastMidnight = GeneratedColumn<int>(
    'minutes_past_midnight',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    minutesPastMidnight,
    notificationId,
    createdAt,
    updatedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_reminder_times';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitReminderTime> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('minutes_past_midnight')) {
      context.handle(
        _minutesPastMidnightMeta,
        minutesPastMidnight.isAcceptableOrUnknown(
          data['minutes_past_midnight']!,
          _minutesPastMidnightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minutesPastMidnightMeta);
    }
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
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
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {habitId, minutesPastMidnight},
  ];
  @override
  HabitReminderTime map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitReminderTime(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      minutesPastMidnight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes_past_midnight'],
      )!,
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $HabitReminderTimesTable createAlias(String alias) {
    return $HabitReminderTimesTable(attachedDatabase, alias);
  }
}

class HabitReminderTime extends DataClass
    implements Insertable<HabitReminderTime> {
  /// Row identifier (UUIDv7 string).
  final String id;

  /// The habit this reminder belongs to.
  final String habitId;

  /// Local time of day to remind, in minutes past midnight (0–1439).
  final int minutesPastMidnight;

  /// Stable 32-bit id for this row's scheduled OS notification, allocated
  /// from the same shared counter as every other notification id in the app.
  /// Null until `ReminderService` first schedules it.
  final int? notificationId;

  /// Created instant in UTC epoch milliseconds.
  final int createdAt;

  /// UTC epoch milliseconds, written whenever the row is (re)created.
  final int updatedAt;

  /// Which install made the last write.
  final String deviceId;
  const HabitReminderTime({
    required this.id,
    required this.habitId,
    required this.minutesPastMidnight,
    this.notificationId,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['minutes_past_midnight'] = Variable<int>(minutesPastMidnight);
    if (!nullToAbsent || notificationId != null) {
      map['notification_id'] = Variable<int>(notificationId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  HabitReminderTimesCompanion toCompanion(bool nullToAbsent) {
    return HabitReminderTimesCompanion(
      id: Value(id),
      habitId: Value(habitId),
      minutesPastMidnight: Value(minutesPastMidnight),
      notificationId: notificationId == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
    );
  }

  factory HabitReminderTime.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitReminderTime(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String>(json['habit_id']),
      minutesPastMidnight: serializer.fromJson<int>(
        json['minutes_past_midnight'],
      ),
      notificationId: serializer.fromJson<int?>(json['notification_id']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habit_id': serializer.toJson<String>(habitId),
      'minutes_past_midnight': serializer.toJson<int>(minutesPastMidnight),
      'notification_id': serializer.toJson<int?>(notificationId),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
    };
  }

  HabitReminderTime copyWith({
    String? id,
    String? habitId,
    int? minutesPastMidnight,
    Value<int?> notificationId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    String? deviceId,
  }) => HabitReminderTime(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    minutesPastMidnight: minutesPastMidnight ?? this.minutesPastMidnight,
    notificationId: notificationId.present
        ? notificationId.value
        : this.notificationId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  HabitReminderTime copyWithCompanion(HabitReminderTimesCompanion data) {
    return HabitReminderTime(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      minutesPastMidnight: data.minutesPastMidnight.present
          ? data.minutesPastMidnight.value
          : this.minutesPastMidnight,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitReminderTime(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('minutesPastMidnight: $minutesPastMidnight, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    minutesPastMidnight,
    notificationId,
    createdAt,
    updatedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitReminderTime &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.minutesPastMidnight == this.minutesPastMidnight &&
          other.notificationId == this.notificationId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId);
}

class HabitReminderTimesCompanion extends UpdateCompanion<HabitReminderTime> {
  final Value<String> id;
  final Value<String> habitId;
  final Value<int> minutesPastMidnight;
  final Value<int?> notificationId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const HabitReminderTimesCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.minutesPastMidnight = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitReminderTimesCompanion.insert({
    required String id,
    required String habitId,
    required int minutesPastMidnight,
    this.notificationId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       habitId = Value(habitId),
       minutesPastMidnight = Value(minutesPastMidnight),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<HabitReminderTime> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<int>? minutesPastMidnight,
    Expression<int>? notificationId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (minutesPastMidnight != null)
        'minutes_past_midnight': minutesPastMidnight,
      if (notificationId != null) 'notification_id': notificationId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitReminderTimesCompanion copyWith({
    Value<String>? id,
    Value<String>? habitId,
    Value<int>? minutesPastMidnight,
    Value<int?>? notificationId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return HabitReminderTimesCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      minutesPastMidnight: minutesPastMidnight ?? this.minutesPastMidnight,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (minutesPastMidnight.present) {
      map['minutes_past_midnight'] = Variable<int>(minutesPastMidnight.value);
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitReminderTimesCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('minutesPastMidnight: $minutesPastMidnight, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorIndex,
    archived,
    updatedAt,
    deviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
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
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;
  final int colorIndex;
  final bool archived;

  /// UTC epoch milliseconds, written on every update (§4).
  final int updatedAt;

  /// Which install made the last write (§4, §5).
  final String deviceId;

  /// Tombstone; null means live row, non-null is deletion UTC ms (§4, §6).
  final int? deletedAt;
  const Project({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.archived,
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_index'] = Variable<int>(colorIndex);
    map['archived'] = Variable<bool>(archived);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      colorIndex: Value(colorIndex),
      archived: Value(archived),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorIndex: serializer.fromJson<int>(json['color_index']),
      archived: serializer.fromJson<bool>(json['archived']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color_index': serializer.toJson<int>(colorIndex),
      'archived': serializer.toJson<bool>(archived),
      'updated_at': serializer.toJson<int>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted_at': serializer.toJson<int?>(deletedAt),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    int? colorIndex,
    bool? archived,
    int? updatedAt,
    String? deviceId,
    Value<int?> deletedAt = const Value.absent(),
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    archived: archived ?? this.archived,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      archived: data.archived.present ? data.archived.value : this.archived,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('archived: $archived, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorIndex,
    archived,
    updatedAt,
    deviceId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorIndex == this.colorIndex &&
          other.archived == this.archived &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorIndex;
  final Value<bool> archived;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.archived = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    this.colorIndex = const Value.absent(),
    this.archived = const Value.absent(),
    required int updatedAt,
    required String deviceId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorIndex,
    Expression<bool>? archived,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorIndex != null) 'color_index': colorIndex,
      if (archived != null) 'archived': archived,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorIndex,
    Value<bool>? archived,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      archived: archived ?? this.archived,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('archived: $archived, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    updatedAt,
    deviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
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
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;

  /// UTC epoch milliseconds, written on every update (§4).
  final int updatedAt;

  /// Which install made the last write (§4, §5).
  final String deviceId;

  /// Tombstone; null means live row, non-null is deletion UTC ms (§4, §6).
  final int? deletedAt;
  const Tag({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      deletedAt: serializer.fromJson<int?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'updated_at': serializer.toJson<int>(updatedAt),
      'device_id': serializer.toJson<String>(deviceId),
      'deleted_at': serializer.toJson<int?>(deletedAt),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    int? updatedAt,
    String? deviceId,
    Value<int?> deletedAt = const Value.absent(),
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, updatedAt, deviceId, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    required int updatedAt,
    required String deviceId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskTagsTable extends TaskTags with TableInfo<$TaskTagsTable, TaskTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, tagId};
  @override
  TaskTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTag(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TaskTagsTable createAlias(String alias) {
    return $TaskTagsTable(attachedDatabase, alias);
  }
}

class TaskTag extends DataClass implements Insertable<TaskTag> {
  final String taskId;
  final String tagId;
  const TaskTag({required this.taskId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  TaskTagsCompanion toCompanion(bool nullToAbsent) {
    return TaskTagsCompanion(taskId: Value(taskId), tagId: Value(tagId));
  }

  factory TaskTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTag(
      taskId: serializer.fromJson<String>(json['task_id']),
      tagId: serializer.fromJson<String>(json['tag_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'task_id': serializer.toJson<String>(taskId),
      'tag_id': serializer.toJson<String>(tagId),
    };
  }

  TaskTag copyWith({String? taskId, String? tagId}) =>
      TaskTag(taskId: taskId ?? this.taskId, tagId: tagId ?? this.tagId);
  TaskTag copyWithCompanion(TaskTagsCompanion data) {
    return TaskTag(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTag(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTag &&
          other.taskId == this.taskId &&
          other.tagId == this.tagId);
}

class TaskTagsCompanion extends UpdateCompanion<TaskTag> {
  final Value<String> taskId;
  final Value<String> tagId;
  final Value<int> rowid;
  const TaskTagsCompanion({
    this.taskId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTagsCompanion.insert({
    required String taskId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       tagId = Value(tagId);
  static Insertable<TaskTag> custom({
    Expression<String>? taskId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTagsCompanion copyWith({
    Value<String>? taskId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return TaskTagsCompanion(
      taskId: taskId ?? this.taskId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimerStatesTable extends TimerStates
    with TableInfo<$TimerStatesTable, TimerState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimerStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  @override
  late final GeneratedColumn<int> startedAtUtc = GeneratedColumn<int>(
    'started_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedDurationSMeta = const VerificationMeta(
    'plannedDurationS',
  );
  @override
  late final GeneratedColumn<int> plannedDurationS = GeneratedColumn<int>(
    'planned_duration_s',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pomodoro'),
  );
  static const VerificationMeta _pausedAccumulatedSMeta =
      const VerificationMeta('pausedAccumulatedS');
  @override
  late final GeneratedColumn<int> pausedAccumulatedS = GeneratedColumn<int>(
    'paused_accumulated_s',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pausedAtUtcMeta = const VerificationMeta(
    'pausedAtUtc',
  );
  @override
  late final GeneratedColumn<int> pausedAtUtc = GeneratedColumn<int>(
    'paused_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    startedAtUtc,
    plannedDurationS,
    mode,
    pausedAccumulatedS,
    pausedAtUtc,
    taskId,
    projectId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timer_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimerState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('planned_duration_s')) {
      context.handle(
        _plannedDurationSMeta,
        plannedDurationS.isAcceptableOrUnknown(
          data['planned_duration_s']!,
          _plannedDurationSMeta,
        ),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('paused_accumulated_s')) {
      context.handle(
        _pausedAccumulatedSMeta,
        pausedAccumulatedS.isAcceptableOrUnknown(
          data['paused_accumulated_s']!,
          _pausedAccumulatedSMeta,
        ),
      );
    }
    if (data.containsKey('paused_at_utc')) {
      context.handle(
        _pausedAtUtcMeta,
        pausedAtUtc.isAcceptableOrUnknown(
          data['paused_at_utc']!,
          _pausedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimerState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimerState(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      startedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_utc'],
      ),
      plannedDurationS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_duration_s'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      pausedAccumulatedS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_accumulated_s'],
      )!,
      pausedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_at_utc'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
    );
  }

  @override
  $TimerStatesTable createAlias(String alias) {
    return $TimerStatesTable(attachedDatabase, alias);
  }
}

class TimerState extends DataClass implements Insertable<TimerState> {
  /// Single row identifier (always 1). Device-local singleton, never synced.
  final int id;

  /// Currently active session ID (UUID string), if any.
  final String? sessionId;

  /// Start timestamp in UTC epoch milliseconds.
  final int? startedAtUtc;

  /// Planned duration in seconds (0 for flow mode).
  final int plannedDurationS;

  /// 'pomodoro' | 'flow'
  final String mode;

  /// Accumulated paused seconds.
  final int pausedAccumulatedS;

  /// UTC epoch milliseconds when pause began, null when running.
  final int? pausedAtUtc;

  /// Optional task ID (UUID string) associated with active session.
  final String? taskId;

  /// Optional project ID (UUID string) associated with active session.
  final String? projectId;
  const TimerState({
    required this.id,
    this.sessionId,
    this.startedAtUtc,
    required this.plannedDurationS,
    required this.mode,
    required this.pausedAccumulatedS,
    this.pausedAtUtc,
    this.taskId,
    this.projectId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || startedAtUtc != null) {
      map['started_at_utc'] = Variable<int>(startedAtUtc);
    }
    map['planned_duration_s'] = Variable<int>(plannedDurationS);
    map['mode'] = Variable<String>(mode);
    map['paused_accumulated_s'] = Variable<int>(pausedAccumulatedS);
    if (!nullToAbsent || pausedAtUtc != null) {
      map['paused_at_utc'] = Variable<int>(pausedAtUtc);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    return map;
  }

  TimerStatesCompanion toCompanion(bool nullToAbsent) {
    return TimerStatesCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      startedAtUtc: startedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAtUtc),
      plannedDurationS: Value(plannedDurationS),
      mode: Value(mode),
      pausedAccumulatedS: Value(pausedAccumulatedS),
      pausedAtUtc: pausedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedAtUtc),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
    );
  }

  factory TimerState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimerState(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String?>(json['session_id']),
      startedAtUtc: serializer.fromJson<int?>(json['started_at_utc']),
      plannedDurationS: serializer.fromJson<int>(json['planned_duration_s']),
      mode: serializer.fromJson<String>(json['mode']),
      pausedAccumulatedS: serializer.fromJson<int>(
        json['paused_accumulated_s'],
      ),
      pausedAtUtc: serializer.fromJson<int?>(json['paused_at_utc']),
      taskId: serializer.fromJson<String?>(json['task_id']),
      projectId: serializer.fromJson<String?>(json['project_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'session_id': serializer.toJson<String?>(sessionId),
      'started_at_utc': serializer.toJson<int?>(startedAtUtc),
      'planned_duration_s': serializer.toJson<int>(plannedDurationS),
      'mode': serializer.toJson<String>(mode),
      'paused_accumulated_s': serializer.toJson<int>(pausedAccumulatedS),
      'paused_at_utc': serializer.toJson<int?>(pausedAtUtc),
      'task_id': serializer.toJson<String?>(taskId),
      'project_id': serializer.toJson<String?>(projectId),
    };
  }

  TimerState copyWith({
    int? id,
    Value<String?> sessionId = const Value.absent(),
    Value<int?> startedAtUtc = const Value.absent(),
    int? plannedDurationS,
    String? mode,
    int? pausedAccumulatedS,
    Value<int?> pausedAtUtc = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
  }) => TimerState(
    id: id ?? this.id,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    startedAtUtc: startedAtUtc.present ? startedAtUtc.value : this.startedAtUtc,
    plannedDurationS: plannedDurationS ?? this.plannedDurationS,
    mode: mode ?? this.mode,
    pausedAccumulatedS: pausedAccumulatedS ?? this.pausedAccumulatedS,
    pausedAtUtc: pausedAtUtc.present ? pausedAtUtc.value : this.pausedAtUtc,
    taskId: taskId.present ? taskId.value : this.taskId,
    projectId: projectId.present ? projectId.value : this.projectId,
  );
  TimerState copyWithCompanion(TimerStatesCompanion data) {
    return TimerState(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      plannedDurationS: data.plannedDurationS.present
          ? data.plannedDurationS.value
          : this.plannedDurationS,
      mode: data.mode.present ? data.mode.value : this.mode,
      pausedAccumulatedS: data.pausedAccumulatedS.present
          ? data.pausedAccumulatedS.value
          : this.pausedAccumulatedS,
      pausedAtUtc: data.pausedAtUtc.present
          ? data.pausedAtUtc.value
          : this.pausedAtUtc,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimerState(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('plannedDurationS: $plannedDurationS, ')
          ..write('mode: $mode, ')
          ..write('pausedAccumulatedS: $pausedAccumulatedS, ')
          ..write('pausedAtUtc: $pausedAtUtc, ')
          ..write('taskId: $taskId, ')
          ..write('projectId: $projectId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    startedAtUtc,
    plannedDurationS,
    mode,
    pausedAccumulatedS,
    pausedAtUtc,
    taskId,
    projectId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimerState &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.startedAtUtc == this.startedAtUtc &&
          other.plannedDurationS == this.plannedDurationS &&
          other.mode == this.mode &&
          other.pausedAccumulatedS == this.pausedAccumulatedS &&
          other.pausedAtUtc == this.pausedAtUtc &&
          other.taskId == this.taskId &&
          other.projectId == this.projectId);
}

class TimerStatesCompanion extends UpdateCompanion<TimerState> {
  final Value<int> id;
  final Value<String?> sessionId;
  final Value<int?> startedAtUtc;
  final Value<int> plannedDurationS;
  final Value<String> mode;
  final Value<int> pausedAccumulatedS;
  final Value<int?> pausedAtUtc;
  final Value<String?> taskId;
  final Value<String?> projectId;
  const TimerStatesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.plannedDurationS = const Value.absent(),
    this.mode = const Value.absent(),
    this.pausedAccumulatedS = const Value.absent(),
    this.pausedAtUtc = const Value.absent(),
    this.taskId = const Value.absent(),
    this.projectId = const Value.absent(),
  });
  TimerStatesCompanion.insert({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.plannedDurationS = const Value.absent(),
    this.mode = const Value.absent(),
    this.pausedAccumulatedS = const Value.absent(),
    this.pausedAtUtc = const Value.absent(),
    this.taskId = const Value.absent(),
    this.projectId = const Value.absent(),
  });
  static Insertable<TimerState> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<int>? startedAtUtc,
    Expression<int>? plannedDurationS,
    Expression<String>? mode,
    Expression<int>? pausedAccumulatedS,
    Expression<int>? pausedAtUtc,
    Expression<String>? taskId,
    Expression<String>? projectId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (plannedDurationS != null) 'planned_duration_s': plannedDurationS,
      if (mode != null) 'mode': mode,
      if (pausedAccumulatedS != null)
        'paused_accumulated_s': pausedAccumulatedS,
      if (pausedAtUtc != null) 'paused_at_utc': pausedAtUtc,
      if (taskId != null) 'task_id': taskId,
      if (projectId != null) 'project_id': projectId,
    });
  }

  TimerStatesCompanion copyWith({
    Value<int>? id,
    Value<String?>? sessionId,
    Value<int?>? startedAtUtc,
    Value<int>? plannedDurationS,
    Value<String>? mode,
    Value<int>? pausedAccumulatedS,
    Value<int?>? pausedAtUtc,
    Value<String?>? taskId,
    Value<String?>? projectId,
  }) {
    return TimerStatesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      plannedDurationS: plannedDurationS ?? this.plannedDurationS,
      mode: mode ?? this.mode,
      pausedAccumulatedS: pausedAccumulatedS ?? this.pausedAccumulatedS,
      pausedAtUtc: pausedAtUtc ?? this.pausedAtUtc,
      taskId: taskId ?? this.taskId,
      projectId: projectId ?? this.projectId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<int>(startedAtUtc.value);
    }
    if (plannedDurationS.present) {
      map['planned_duration_s'] = Variable<int>(plannedDurationS.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (pausedAccumulatedS.present) {
      map['paused_accumulated_s'] = Variable<int>(pausedAccumulatedS.value);
    }
    if (pausedAtUtc.present) {
      map['paused_at_utc'] = Variable<int>(pausedAtUtc.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimerStatesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('plannedDurationS: $plannedDurationS, ')
          ..write('mode: $mode, ')
          ..write('pausedAccumulatedS: $pausedAccumulatedS, ')
          ..write('pausedAtUtc: $pausedAtUtc, ')
          ..write('taskId: $taskId, ')
          ..write('projectId: $projectId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventsTable events = $EventsTable(this);
  late final $FocusSessionsTable focusSessions = $FocusSessionsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $TaskReminderOffsetsTable taskReminderOffsets =
      $TaskReminderOffsetsTable(this);
  late final $HabitsTable habits = $HabitsTable(this);
  late final $HabitEntriesTable habitEntries = $HabitEntriesTable(this);
  late final $HabitReminderTimesTable habitReminderTimes =
      $HabitReminderTimesTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TaskTagsTable taskTags = $TaskTagsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $TimerStatesTable timerStates = $TimerStatesTable(this);
  late final Index eventsLocalDateIdx = Index(
    'events_local_date_idx',
    'CREATE INDEX events_local_date_idx ON events (local_date)',
  );
  late final Index eventsTypeLocalDateIdx = Index(
    'events_type_local_date_idx',
    'CREATE INDEX events_type_local_date_idx ON events (type, local_date)',
  );
  late final Index eventsSubjectIdx = Index(
    'events_subject_idx',
    'CREATE INDEX events_subject_idx ON events (subject_type, subject_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    events,
    focusSessions,
    tasks,
    taskReminderOffsets,
    habits,
    habitEntries,
    habitReminderTimes,
    projects,
    tags,
    taskTags,
    settings,
    timerStates,
    eventsLocalDateIdx,
    eventsTypeLocalDateIdx,
    eventsSubjectIdx,
  ];
}

typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      required String id,
      required String type,
      required int occurredAt,
      required int recordedAt,
      required String localDate,
      required String tzId,
      required int tzOffsetMin,
      Value<String?> subjectType,
      Value<String?> subjectId,
      required String payload,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<int> occurredAt,
      Value<int> recordedAt,
      Value<String> localDate,
      Value<String> tzId,
      Value<int> tzOffsetMin,
      Value<String?> subjectType,
      Value<String?> subjectId,
      Value<String> payload,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tzId => $composableBuilder(
    column: $table.tzId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tzId => $composableBuilder(
    column: $table.tzId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<String> get tzId =>
      $composableBuilder(column: $table.tzId, builder: (column) => column);

  GeneratedColumn<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          Event,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
          Event,
          PrefetchHooks Function()
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<int> recordedAt = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<String> tzId = const Value.absent(),
                Value<int> tzOffsetMin = const Value.absent(),
                Value<String?> subjectType = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                type: type,
                occurredAt: occurredAt,
                recordedAt: recordedAt,
                localDate: localDate,
                tzId: tzId,
                tzOffsetMin: tzOffsetMin,
                subjectType: subjectType,
                subjectId: subjectId,
                payload: payload,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required int occurredAt,
                required int recordedAt,
                required String localDate,
                required String tzId,
                required int tzOffsetMin,
                Value<String?> subjectType = const Value.absent(),
                Value<String?> subjectId = const Value.absent(),
                required String payload,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion.insert(
                id: id,
                type: type,
                occurredAt: occurredAt,
                recordedAt: recordedAt,
                localDate: localDate,
                tzId: tzId,
                tzOffsetMin: tzOffsetMin,
                subjectType: subjectType,
                subjectId: subjectId,
                payload: payload,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      Event,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
      Event,
      PrefetchHooks Function()
    >;
typedef $$FocusSessionsTableCreateCompanionBuilder =
    FocusSessionsCompanion Function({
      required String id,
      Value<String?> taskId,
      Value<String?> projectId,
      required String mode,
      Value<int> plannedDurationS,
      Value<int> actualDurationS,
      required int startedAt,
      required int endedAt,
      required String localDate,
      required int tzOffsetMin,
      Value<String> tzId,
      required String outcome,
      Value<int> interruptionsInternal,
      Value<int> interruptionsExternal,
      Value<int?> focusRating,
      Value<String?> note,
      Value<bool> isManual,
      required int updatedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$FocusSessionsTableUpdateCompanionBuilder =
    FocusSessionsCompanion Function({
      Value<String> id,
      Value<String?> taskId,
      Value<String?> projectId,
      Value<String> mode,
      Value<int> plannedDurationS,
      Value<int> actualDurationS,
      Value<int> startedAt,
      Value<int> endedAt,
      Value<String> localDate,
      Value<int> tzOffsetMin,
      Value<String> tzId,
      Value<String> outcome,
      Value<int> interruptionsInternal,
      Value<int> interruptionsExternal,
      Value<int?> focusRating,
      Value<String?> note,
      Value<bool> isManual,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$FocusSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedDurationS => $composableBuilder(
    column: $table.plannedDurationS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualDurationS => $composableBuilder(
    column: $table.actualDurationS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tzId => $composableBuilder(
    column: $table.tzId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interruptionsInternal => $composableBuilder(
    column: $table.interruptionsInternal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interruptionsExternal => $composableBuilder(
    column: $table.interruptionsExternal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusRating => $composableBuilder(
    column: $table.focusRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FocusSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedDurationS => $composableBuilder(
    column: $table.plannedDurationS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualDurationS => $composableBuilder(
    column: $table.actualDurationS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tzId => $composableBuilder(
    column: $table.tzId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interruptionsInternal => $composableBuilder(
    column: $table.interruptionsInternal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interruptionsExternal => $composableBuilder(
    column: $table.interruptionsExternal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusRating => $composableBuilder(
    column: $table.focusRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isManual => $composableBuilder(
    column: $table.isManual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FocusSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get plannedDurationS => $composableBuilder(
    column: $table.plannedDurationS,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualDurationS => $composableBuilder(
    column: $table.actualDurationS,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tzId =>
      $composableBuilder(column: $table.tzId, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get interruptionsInternal => $composableBuilder(
    column: $table.interruptionsInternal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get interruptionsExternal => $composableBuilder(
    column: $table.interruptionsExternal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusRating => $composableBuilder(
    column: $table.focusRating,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isManual =>
      $composableBuilder(column: $table.isManual, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$FocusSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FocusSessionsTable,
          FocusSession,
          $$FocusSessionsTableFilterComposer,
          $$FocusSessionsTableOrderingComposer,
          $$FocusSessionsTableAnnotationComposer,
          $$FocusSessionsTableCreateCompanionBuilder,
          $$FocusSessionsTableUpdateCompanionBuilder,
          (
            FocusSession,
            BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSession>,
          ),
          FocusSession,
          PrefetchHooks Function()
        > {
  $$FocusSessionsTableTableManager(_$AppDatabase db, $FocusSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> plannedDurationS = const Value.absent(),
                Value<int> actualDurationS = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int> endedAt = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<int> tzOffsetMin = const Value.absent(),
                Value<String> tzId = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<int> interruptionsInternal = const Value.absent(),
                Value<int> interruptionsExternal = const Value.absent(),
                Value<int?> focusRating = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isManual = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion(
                id: id,
                taskId: taskId,
                projectId: projectId,
                mode: mode,
                plannedDurationS: plannedDurationS,
                actualDurationS: actualDurationS,
                startedAt: startedAt,
                endedAt: endedAt,
                localDate: localDate,
                tzOffsetMin: tzOffsetMin,
                tzId: tzId,
                outcome: outcome,
                interruptionsInternal: interruptionsInternal,
                interruptionsExternal: interruptionsExternal,
                focusRating: focusRating,
                note: note,
                isManual: isManual,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> taskId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                required String mode,
                Value<int> plannedDurationS = const Value.absent(),
                Value<int> actualDurationS = const Value.absent(),
                required int startedAt,
                required int endedAt,
                required String localDate,
                required int tzOffsetMin,
                Value<String> tzId = const Value.absent(),
                required String outcome,
                Value<int> interruptionsInternal = const Value.absent(),
                Value<int> interruptionsExternal = const Value.absent(),
                Value<int?> focusRating = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isManual = const Value.absent(),
                required int updatedAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion.insert(
                id: id,
                taskId: taskId,
                projectId: projectId,
                mode: mode,
                plannedDurationS: plannedDurationS,
                actualDurationS: actualDurationS,
                startedAt: startedAt,
                endedAt: endedAt,
                localDate: localDate,
                tzOffsetMin: tzOffsetMin,
                tzId: tzId,
                outcome: outcome,
                interruptionsInternal: interruptionsInternal,
                interruptionsExternal: interruptionsExternal,
                focusRating: focusRating,
                note: note,
                isManual: isManual,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FocusSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FocusSessionsTable,
      FocusSession,
      $$FocusSessionsTableFilterComposer,
      $$FocusSessionsTableOrderingComposer,
      $$FocusSessionsTableAnnotationComposer,
      $$FocusSessionsTableCreateCompanionBuilder,
      $$FocusSessionsTableUpdateCompanionBuilder,
      (
        FocusSession,
        BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSession>,
      ),
      FocusSession,
      PrefetchHooks Function()
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String id,
      required String title,
      Value<String?> notes,
      Value<String?> projectId,
      Value<String?> parentId,
      Value<int> priority,
      Value<int?> dueAt,
      Value<bool> dueIsAllDay,
      Value<int?> estimatePomodoros,
      Value<String> status,
      required int createdAt,
      required String createdLocalDate,
      Value<int?> completedAt,
      Value<String?> completedLocalDate,
      Value<int> rescheduleCount,
      Value<String?> recurrenceRule,
      Value<String?> recurrenceMode,
      Value<String?> recurrenceParentId,
      Value<double> sortOrder,
      required int updatedAt,
      required String deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> notes,
      Value<String?> projectId,
      Value<String?> parentId,
      Value<int> priority,
      Value<int?> dueAt,
      Value<bool> dueIsAllDay,
      Value<int?> estimatePomodoros,
      Value<String> status,
      Value<int> createdAt,
      Value<String> createdLocalDate,
      Value<int?> completedAt,
      Value<String?> completedLocalDate,
      Value<int> rescheduleCount,
      Value<String?> recurrenceRule,
      Value<String?> recurrenceMode,
      Value<String?> recurrenceParentId,
      Value<double> sortOrder,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dueIsAllDay => $composableBuilder(
    column: $table.dueIsAllDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatePomodoros => $composableBuilder(
    column: $table.estimatePomodoros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdLocalDate => $composableBuilder(
    column: $table.createdLocalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedLocalDate => $composableBuilder(
    column: $table.completedLocalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rescheduleCount => $composableBuilder(
    column: $table.rescheduleCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceMode => $composableBuilder(
    column: $table.recurrenceMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceParentId => $composableBuilder(
    column: $table.recurrenceParentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dueIsAllDay => $composableBuilder(
    column: $table.dueIsAllDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatePomodoros => $composableBuilder(
    column: $table.estimatePomodoros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdLocalDate => $composableBuilder(
    column: $table.createdLocalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedLocalDate => $composableBuilder(
    column: $table.completedLocalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rescheduleCount => $composableBuilder(
    column: $table.rescheduleCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceMode => $composableBuilder(
    column: $table.recurrenceMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceParentId => $composableBuilder(
    column: $table.recurrenceParentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get dueIsAllDay => $composableBuilder(
    column: $table.dueIsAllDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatePomodoros => $composableBuilder(
    column: $table.estimatePomodoros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdLocalDate => $composableBuilder(
    column: $table.createdLocalDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completedLocalDate => $composableBuilder(
    column: $table.completedLocalDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rescheduleCount => $composableBuilder(
    column: $table.rescheduleCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceRule => $composableBuilder(
    column: $table.recurrenceRule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceMode => $composableBuilder(
    column: $table.recurrenceMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceParentId => $composableBuilder(
    column: $table.recurrenceParentId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
          Task,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> dueAt = const Value.absent(),
                Value<bool> dueIsAllDay = const Value.absent(),
                Value<int?> estimatePomodoros = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> createdLocalDate = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<String?> completedLocalDate = const Value.absent(),
                Value<int> rescheduleCount = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceMode = const Value.absent(),
                Value<String?> recurrenceParentId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                title: title,
                notes: notes,
                projectId: projectId,
                parentId: parentId,
                priority: priority,
                dueAt: dueAt,
                dueIsAllDay: dueIsAllDay,
                estimatePomodoros: estimatePomodoros,
                status: status,
                createdAt: createdAt,
                createdLocalDate: createdLocalDate,
                completedAt: completedAt,
                completedLocalDate: completedLocalDate,
                rescheduleCount: rescheduleCount,
                recurrenceRule: recurrenceRule,
                recurrenceMode: recurrenceMode,
                recurrenceParentId: recurrenceParentId,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> notes = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> dueAt = const Value.absent(),
                Value<bool> dueIsAllDay = const Value.absent(),
                Value<int?> estimatePomodoros = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int createdAt,
                required String createdLocalDate,
                Value<int?> completedAt = const Value.absent(),
                Value<String?> completedLocalDate = const Value.absent(),
                Value<int> rescheduleCount = const Value.absent(),
                Value<String?> recurrenceRule = const Value.absent(),
                Value<String?> recurrenceMode = const Value.absent(),
                Value<String?> recurrenceParentId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                required int updatedAt,
                required String deviceId,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                title: title,
                notes: notes,
                projectId: projectId,
                parentId: parentId,
                priority: priority,
                dueAt: dueAt,
                dueIsAllDay: dueIsAllDay,
                estimatePomodoros: estimatePomodoros,
                status: status,
                createdAt: createdAt,
                createdLocalDate: createdLocalDate,
                completedAt: completedAt,
                completedLocalDate: completedLocalDate,
                rescheduleCount: rescheduleCount,
                recurrenceRule: recurrenceRule,
                recurrenceMode: recurrenceMode,
                recurrenceParentId: recurrenceParentId,
                sortOrder: sortOrder,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
      Task,
      PrefetchHooks Function()
    >;
typedef $$TaskReminderOffsetsTableCreateCompanionBuilder =
    TaskReminderOffsetsCompanion Function({
      required String id,
      required String taskId,
      required int offsetMin,
      Value<int?> notificationId,
      required int createdAt,
      required int updatedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$TaskReminderOffsetsTableUpdateCompanionBuilder =
    TaskReminderOffsetsCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<int> offsetMin,
      Value<int?> notificationId,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$TaskReminderOffsetsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskReminderOffsetsTable> {
  $$TaskReminderOffsetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMin => $composableBuilder(
    column: $table.offsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskReminderOffsetsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskReminderOffsetsTable> {
  $$TaskReminderOffsetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMin => $composableBuilder(
    column: $table.offsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskReminderOffsetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskReminderOffsetsTable> {
  $$TaskReminderOffsetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<int> get offsetMin =>
      $composableBuilder(column: $table.offsetMin, builder: (column) => column);

  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$TaskReminderOffsetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskReminderOffsetsTable,
          TaskReminderOffset,
          $$TaskReminderOffsetsTableFilterComposer,
          $$TaskReminderOffsetsTableOrderingComposer,
          $$TaskReminderOffsetsTableAnnotationComposer,
          $$TaskReminderOffsetsTableCreateCompanionBuilder,
          $$TaskReminderOffsetsTableUpdateCompanionBuilder,
          (
            TaskReminderOffset,
            BaseReferences<
              _$AppDatabase,
              $TaskReminderOffsetsTable,
              TaskReminderOffset
            >,
          ),
          TaskReminderOffset,
          PrefetchHooks Function()
        > {
  $$TaskReminderOffsetsTableTableManager(
    _$AppDatabase db,
    $TaskReminderOffsetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskReminderOffsetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskReminderOffsetsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TaskReminderOffsetsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<int> offsetMin = const Value.absent(),
                Value<int?> notificationId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskReminderOffsetsCompanion(
                id: id,
                taskId: taskId,
                offsetMin: offsetMin,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required int offsetMin,
                Value<int?> notificationId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => TaskReminderOffsetsCompanion.insert(
                id: id,
                taskId: taskId,
                offsetMin: offsetMin,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskReminderOffsetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskReminderOffsetsTable,
      TaskReminderOffset,
      $$TaskReminderOffsetsTableFilterComposer,
      $$TaskReminderOffsetsTableOrderingComposer,
      $$TaskReminderOffsetsTableAnnotationComposer,
      $$TaskReminderOffsetsTableCreateCompanionBuilder,
      $$TaskReminderOffsetsTableUpdateCompanionBuilder,
      (
        TaskReminderOffset,
        BaseReferences<
          _$AppDatabase,
          $TaskReminderOffsetsTable,
          TaskReminderOffset
        >,
      ),
      TaskReminderOffset,
      PrefetchHooks Function()
    >;
typedef $$HabitsTableCreateCompanionBuilder =
    HabitsCompanion Function({
      required String id,
      required String title,
      Value<String?> notes,
      Value<int> colorIndex,
      Value<String> iconName,
      required String scheduleRule,
      required String anchorDate,
      Value<int> targetCount,
      Value<String?> unitLabel,
      Value<int> skipAllowancePerMonth,
      Value<String> status,
      Value<double> sortOrder,
      required int createdAt,
      required String createdLocalDate,
      Value<int?> archivedAt,
      required int updatedAt,
      required String deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$HabitsTableUpdateCompanionBuilder =
    HabitsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> notes,
      Value<int> colorIndex,
      Value<String> iconName,
      Value<String> scheduleRule,
      Value<String> anchorDate,
      Value<int> targetCount,
      Value<String?> unitLabel,
      Value<int> skipAllowancePerMonth,
      Value<String> status,
      Value<double> sortOrder,
      Value<int> createdAt,
      Value<String> createdLocalDate,
      Value<int?> archivedAt,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$HabitsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleRule => $composableBuilder(
    column: $table.scheduleRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get anchorDate => $composableBuilder(
    column: $table.anchorDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetCount => $composableBuilder(
    column: $table.targetCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skipAllowancePerMonth => $composableBuilder(
    column: $table.skipAllowancePerMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdLocalDate => $composableBuilder(
    column: $table.createdLocalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleRule => $composableBuilder(
    column: $table.scheduleRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anchorDate => $composableBuilder(
    column: $table.anchorDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetCount => $composableBuilder(
    column: $table.targetCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skipAllowancePerMonth => $composableBuilder(
    column: $table.skipAllowancePerMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdLocalDate => $composableBuilder(
    column: $table.createdLocalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<String> get scheduleRule => $composableBuilder(
    column: $table.scheduleRule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get anchorDate => $composableBuilder(
    column: $table.anchorDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetCount => $composableBuilder(
    column: $table.targetCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitLabel =>
      $composableBuilder(column: $table.unitLabel, builder: (column) => column);

  GeneratedColumn<int> get skipAllowancePerMonth => $composableBuilder(
    column: $table.skipAllowancePerMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdLocalDate => $composableBuilder(
    column: $table.createdLocalDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$HabitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitsTable,
          Habit,
          $$HabitsTableFilterComposer,
          $$HabitsTableOrderingComposer,
          $$HabitsTableAnnotationComposer,
          $$HabitsTableCreateCompanionBuilder,
          $$HabitsTableUpdateCompanionBuilder,
          (Habit, BaseReferences<_$AppDatabase, $HabitsTable, Habit>),
          Habit,
          PrefetchHooks Function()
        > {
  $$HabitsTableTableManager(_$AppDatabase db, $HabitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<String> scheduleRule = const Value.absent(),
                Value<String> anchorDate = const Value.absent(),
                Value<int> targetCount = const Value.absent(),
                Value<String?> unitLabel = const Value.absent(),
                Value<int> skipAllowancePerMonth = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> createdLocalDate = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion(
                id: id,
                title: title,
                notes: notes,
                colorIndex: colorIndex,
                iconName: iconName,
                scheduleRule: scheduleRule,
                anchorDate: anchorDate,
                targetCount: targetCount,
                unitLabel: unitLabel,
                skipAllowancePerMonth: skipAllowancePerMonth,
                status: status,
                sortOrder: sortOrder,
                createdAt: createdAt,
                createdLocalDate: createdLocalDate,
                archivedAt: archivedAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> notes = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                required String scheduleRule,
                required String anchorDate,
                Value<int> targetCount = const Value.absent(),
                Value<String?> unitLabel = const Value.absent(),
                Value<int> skipAllowancePerMonth = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                required int createdAt,
                required String createdLocalDate,
                Value<int?> archivedAt = const Value.absent(),
                required int updatedAt,
                required String deviceId,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion.insert(
                id: id,
                title: title,
                notes: notes,
                colorIndex: colorIndex,
                iconName: iconName,
                scheduleRule: scheduleRule,
                anchorDate: anchorDate,
                targetCount: targetCount,
                unitLabel: unitLabel,
                skipAllowancePerMonth: skipAllowancePerMonth,
                status: status,
                sortOrder: sortOrder,
                createdAt: createdAt,
                createdLocalDate: createdLocalDate,
                archivedAt: archivedAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitsTable,
      Habit,
      $$HabitsTableFilterComposer,
      $$HabitsTableOrderingComposer,
      $$HabitsTableAnnotationComposer,
      $$HabitsTableCreateCompanionBuilder,
      $$HabitsTableUpdateCompanionBuilder,
      (Habit, BaseReferences<_$AppDatabase, $HabitsTable, Habit>),
      Habit,
      PrefetchHooks Function()
    >;
typedef $$HabitEntriesTableCreateCompanionBuilder =
    HabitEntriesCompanion Function({
      required String id,
      required String habitId,
      required String localDate,
      Value<int> checkCount,
      Value<bool> skipped,
      Value<String?> note,
      Value<int?> lastCheckedAt,
      required int tzOffsetMin,
      required int createdAt,
      required int updatedAt,
      required String deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$HabitEntriesTableUpdateCompanionBuilder =
    HabitEntriesCompanion Function({
      Value<String> id,
      Value<String> habitId,
      Value<String> localDate,
      Value<int> checkCount,
      Value<bool> skipped,
      Value<String?> note,
      Value<int?> lastCheckedAt,
      Value<int> tzOffsetMin,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$HabitEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $HabitEntriesTable> {
  $$HabitEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkCount => $composableBuilder(
    column: $table.checkCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitEntriesTable> {
  $$HabitEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkCount => $composableBuilder(
    column: $table.checkCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get skipped => $composableBuilder(
    column: $table.skipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitEntriesTable> {
  $$HabitEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<int> get checkCount => $composableBuilder(
    column: $table.checkCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get skipped =>
      $composableBuilder(column: $table.skipped, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$HabitEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitEntriesTable,
          HabitEntry,
          $$HabitEntriesTableFilterComposer,
          $$HabitEntriesTableOrderingComposer,
          $$HabitEntriesTableAnnotationComposer,
          $$HabitEntriesTableCreateCompanionBuilder,
          $$HabitEntriesTableUpdateCompanionBuilder,
          (
            HabitEntry,
            BaseReferences<_$AppDatabase, $HabitEntriesTable, HabitEntry>,
          ),
          HabitEntry,
          PrefetchHooks Function()
        > {
  $$HabitEntriesTableTableManager(_$AppDatabase db, $HabitEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<int> checkCount = const Value.absent(),
                Value<bool> skipped = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> lastCheckedAt = const Value.absent(),
                Value<int> tzOffsetMin = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitEntriesCompanion(
                id: id,
                habitId: habitId,
                localDate: localDate,
                checkCount: checkCount,
                skipped: skipped,
                note: note,
                lastCheckedAt: lastCheckedAt,
                tzOffsetMin: tzOffsetMin,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String habitId,
                required String localDate,
                Value<int> checkCount = const Value.absent(),
                Value<bool> skipped = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> lastCheckedAt = const Value.absent(),
                required int tzOffsetMin,
                required int createdAt,
                required int updatedAt,
                required String deviceId,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitEntriesCompanion.insert(
                id: id,
                habitId: habitId,
                localDate: localDate,
                checkCount: checkCount,
                skipped: skipped,
                note: note,
                lastCheckedAt: lastCheckedAt,
                tzOffsetMin: tzOffsetMin,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitEntriesTable,
      HabitEntry,
      $$HabitEntriesTableFilterComposer,
      $$HabitEntriesTableOrderingComposer,
      $$HabitEntriesTableAnnotationComposer,
      $$HabitEntriesTableCreateCompanionBuilder,
      $$HabitEntriesTableUpdateCompanionBuilder,
      (
        HabitEntry,
        BaseReferences<_$AppDatabase, $HabitEntriesTable, HabitEntry>,
      ),
      HabitEntry,
      PrefetchHooks Function()
    >;
typedef $$HabitReminderTimesTableCreateCompanionBuilder =
    HabitReminderTimesCompanion Function({
      required String id,
      required String habitId,
      required int minutesPastMidnight,
      Value<int?> notificationId,
      required int createdAt,
      required int updatedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$HabitReminderTimesTableUpdateCompanionBuilder =
    HabitReminderTimesCompanion Function({
      Value<String> id,
      Value<String> habitId,
      Value<int> minutesPastMidnight,
      Value<int?> notificationId,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$HabitReminderTimesTableFilterComposer
    extends Composer<_$AppDatabase, $HabitReminderTimesTable> {
  $$HabitReminderTimesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutesPastMidnight => $composableBuilder(
    column: $table.minutesPastMidnight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitReminderTimesTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitReminderTimesTable> {
  $$HabitReminderTimesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutesPastMidnight => $composableBuilder(
    column: $table.minutesPastMidnight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitReminderTimesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitReminderTimesTable> {
  $$HabitReminderTimesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<int> get minutesPastMidnight => $composableBuilder(
    column: $table.minutesPastMidnight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$HabitReminderTimesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitReminderTimesTable,
          HabitReminderTime,
          $$HabitReminderTimesTableFilterComposer,
          $$HabitReminderTimesTableOrderingComposer,
          $$HabitReminderTimesTableAnnotationComposer,
          $$HabitReminderTimesTableCreateCompanionBuilder,
          $$HabitReminderTimesTableUpdateCompanionBuilder,
          (
            HabitReminderTime,
            BaseReferences<
              _$AppDatabase,
              $HabitReminderTimesTable,
              HabitReminderTime
            >,
          ),
          HabitReminderTime,
          PrefetchHooks Function()
        > {
  $$HabitReminderTimesTableTableManager(
    _$AppDatabase db,
    $HabitReminderTimesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitReminderTimesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitReminderTimesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitReminderTimesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<int> minutesPastMidnight = const Value.absent(),
                Value<int?> notificationId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitReminderTimesCompanion(
                id: id,
                habitId: habitId,
                minutesPastMidnight: minutesPastMidnight,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String habitId,
                required int minutesPastMidnight,
                Value<int?> notificationId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => HabitReminderTimesCompanion.insert(
                id: id,
                habitId: habitId,
                minutesPastMidnight: minutesPastMidnight,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitReminderTimesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitReminderTimesTable,
      HabitReminderTime,
      $$HabitReminderTimesTableFilterComposer,
      $$HabitReminderTimesTableOrderingComposer,
      $$HabitReminderTimesTableAnnotationComposer,
      $$HabitReminderTimesTableCreateCompanionBuilder,
      $$HabitReminderTimesTableUpdateCompanionBuilder,
      (
        HabitReminderTime,
        BaseReferences<
          _$AppDatabase,
          $HabitReminderTimesTable,
          HabitReminderTime
        >,
      ),
      HabitReminderTime,
      PrefetchHooks Function()
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String name,
      Value<int> colorIndex,
      Value<bool> archived,
      required int updatedAt,
      required String deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> colorIndex,
      Value<bool> archived,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
          Project,
          PrefetchHooks Function()
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                colorIndex: colorIndex,
                archived: archived,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> colorIndex = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required int updatedAt,
                required String deviceId,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                colorIndex: colorIndex,
                archived: archived,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
      Project,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      required int updatedAt,
      required String deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
          Tag,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int updatedAt,
                required String deviceId,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                updatedAt: updatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, BaseReferences<_$AppDatabase, $TagsTable, Tag>),
      Tag,
      PrefetchHooks Function()
    >;
typedef $$TaskTagsTableCreateCompanionBuilder =
    TaskTagsCompanion Function({
      required String taskId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$TaskTagsTableUpdateCompanionBuilder =
    TaskTagsCompanion Function({
      Value<String> taskId,
      Value<String> tagId,
      Value<int> rowid,
    });

class $$TaskTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);
}

class $$TaskTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskTagsTable,
          TaskTag,
          $$TaskTagsTableFilterComposer,
          $$TaskTagsTableOrderingComposer,
          $$TaskTagsTableAnnotationComposer,
          $$TaskTagsTableCreateCompanionBuilder,
          $$TaskTagsTableUpdateCompanionBuilder,
          (TaskTag, BaseReferences<_$AppDatabase, $TaskTagsTable, TaskTag>),
          TaskTag,
          PrefetchHooks Function()
        > {
  $$TaskTagsTableTableManager(_$AppDatabase db, $TaskTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  TaskTagsCompanion(taskId: taskId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String taskId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => TaskTagsCompanion.insert(
                taskId: taskId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskTagsTable,
      TaskTag,
      $$TaskTagsTableFilterComposer,
      $$TaskTagsTableOrderingComposer,
      $$TaskTagsTableAnnotationComposer,
      $$TaskTagsTableCreateCompanionBuilder,
      $$TaskTagsTableUpdateCompanionBuilder,
      (TaskTag, BaseReferences<_$AppDatabase, $TaskTagsTable, TaskTag>),
      TaskTag,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$TimerStatesTableCreateCompanionBuilder =
    TimerStatesCompanion Function({
      Value<int> id,
      Value<String?> sessionId,
      Value<int?> startedAtUtc,
      Value<int> plannedDurationS,
      Value<String> mode,
      Value<int> pausedAccumulatedS,
      Value<int?> pausedAtUtc,
      Value<String?> taskId,
      Value<String?> projectId,
    });
typedef $$TimerStatesTableUpdateCompanionBuilder =
    TimerStatesCompanion Function({
      Value<int> id,
      Value<String?> sessionId,
      Value<int?> startedAtUtc,
      Value<int> plannedDurationS,
      Value<String> mode,
      Value<int> pausedAccumulatedS,
      Value<int?> pausedAtUtc,
      Value<String?> taskId,
      Value<String?> projectId,
    });

class $$TimerStatesTableFilterComposer
    extends Composer<_$AppDatabase, $TimerStatesTable> {
  $$TimerStatesTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedDurationS => $composableBuilder(
    column: $table.plannedDurationS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedAccumulatedS => $composableBuilder(
    column: $table.pausedAccumulatedS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedAtUtc => $composableBuilder(
    column: $table.pausedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TimerStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TimerStatesTable> {
  $$TimerStatesTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedDurationS => $composableBuilder(
    column: $table.plannedDurationS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedAccumulatedS => $composableBuilder(
    column: $table.pausedAccumulatedS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedAtUtc => $composableBuilder(
    column: $table.pausedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TimerStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimerStatesTable> {
  $$TimerStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plannedDurationS => $composableBuilder(
    column: $table.plannedDurationS,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get pausedAccumulatedS => $composableBuilder(
    column: $table.pausedAccumulatedS,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pausedAtUtc => $composableBuilder(
    column: $table.pausedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);
}

class $$TimerStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimerStatesTable,
          TimerState,
          $$TimerStatesTableFilterComposer,
          $$TimerStatesTableOrderingComposer,
          $$TimerStatesTableAnnotationComposer,
          $$TimerStatesTableCreateCompanionBuilder,
          $$TimerStatesTableUpdateCompanionBuilder,
          (
            TimerState,
            BaseReferences<_$AppDatabase, $TimerStatesTable, TimerState>,
          ),
          TimerState,
          PrefetchHooks Function()
        > {
  $$TimerStatesTableTableManager(_$AppDatabase db, $TimerStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimerStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimerStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimerStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<int?> startedAtUtc = const Value.absent(),
                Value<int> plannedDurationS = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> pausedAccumulatedS = const Value.absent(),
                Value<int?> pausedAtUtc = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
              }) => TimerStatesCompanion(
                id: id,
                sessionId: sessionId,
                startedAtUtc: startedAtUtc,
                plannedDurationS: plannedDurationS,
                mode: mode,
                pausedAccumulatedS: pausedAccumulatedS,
                pausedAtUtc: pausedAtUtc,
                taskId: taskId,
                projectId: projectId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<int?> startedAtUtc = const Value.absent(),
                Value<int> plannedDurationS = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> pausedAccumulatedS = const Value.absent(),
                Value<int?> pausedAtUtc = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
              }) => TimerStatesCompanion.insert(
                id: id,
                sessionId: sessionId,
                startedAtUtc: startedAtUtc,
                plannedDurationS: plannedDurationS,
                mode: mode,
                pausedAccumulatedS: pausedAccumulatedS,
                pausedAtUtc: pausedAtUtc,
                taskId: taskId,
                projectId: projectId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TimerStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimerStatesTable,
      TimerState,
      $$TimerStatesTableFilterComposer,
      $$TimerStatesTableOrderingComposer,
      $$TimerStatesTableAnnotationComposer,
      $$TimerStatesTableCreateCompanionBuilder,
      $$TimerStatesTableUpdateCompanionBuilder,
      (
        TimerState,
        BaseReferences<_$AppDatabase, $TimerStatesTable, TimerState>,
      ),
      TimerState,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db, _db.focusSessions);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$TaskReminderOffsetsTableTableManager get taskReminderOffsets =>
      $$TaskReminderOffsetsTableTableManager(_db, _db.taskReminderOffsets);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db, _db.habits);
  $$HabitEntriesTableTableManager get habitEntries =>
      $$HabitEntriesTableTableManager(_db, _db.habitEntries);
  $$HabitReminderTimesTableTableManager get habitReminderTimes =>
      $$HabitReminderTimesTableTableManager(_db, _db.habitReminderTimes);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TaskTagsTableTableManager get taskTags =>
      $$TaskTagsTableTableManager(_db, _db.taskTags);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$TimerStatesTableTableManager get timerStates =>
      $$TimerStatesTableTableManager(_db, _db.timerStates);
}
