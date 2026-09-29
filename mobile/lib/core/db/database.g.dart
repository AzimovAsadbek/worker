// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PendingEventsTable extends PendingEvents
    with TableInfo<$PendingEventsTable, PendingEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientEventIdMeta = const VerificationMeta(
    'clientEventId',
  );
  @override
  late final GeneratedColumn<String> clientEventId = GeneratedColumn<String>(
    'client_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
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
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<String> siteId = GeneratedColumn<String>(
    'site_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _siteNameMeta = const VerificationMeta(
    'siteName',
  );
  @override
  late final GeneratedColumn<String> siteName = GeneratedColumn<String>(
    'site_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
    'accuracy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isMockedMeta = const VerificationMeta(
    'isMocked',
  );
  @override
  late final GeneratedColumn<bool> isMocked = GeneratedColumn<bool>(
    'is_mocked',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_mocked" IN (0, 1))',
    ),
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverShiftIdMeta = const VerificationMeta(
    'serverShiftId',
  );
  @override
  late final GeneratedColumn<String> serverShiftId = GeneratedColumn<String>(
    'server_shift_id',
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
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acknowledgedMeta = const VerificationMeta(
    'acknowledged',
  );
  @override
  late final GeneratedColumn<bool> acknowledged = GeneratedColumn<bool>(
    'acknowledged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("acknowledged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientEventId,
    userId,
    type,
    siteId,
    siteName,
    occurredAt,
    latitude,
    longitude,
    accuracy,
    isMocked,
    deviceId,
    status,
    attempts,
    errorCode,
    errorMessage,
    serverShiftId,
    createdAt,
    nextAttemptAt,
    syncedAt,
    acknowledged,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_event_id')) {
      context.handle(
        _clientEventIdMeta,
        clientEventId.isAcceptableOrUnknown(
          data['client_event_id']!,
          _clientEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientEventIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_siteIdMeta);
    }
    if (data.containsKey('site_name')) {
      context.handle(
        _siteNameMeta,
        siteName.isAcceptableOrUnknown(data['site_name']!, _siteNameMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    }
    if (data.containsKey('is_mocked')) {
      context.handle(
        _isMockedMeta,
        isMocked.isAcceptableOrUnknown(data['is_mocked']!, _isMockedMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('server_shift_id')) {
      context.handle(
        _serverShiftIdMeta,
        serverShiftId.isAcceptableOrUnknown(
          data['server_shift_id']!,
          _serverShiftIdMeta,
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
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('acknowledged')) {
      context.handle(
        _acknowledgedMeta,
        acknowledged.isAcceptableOrUnknown(
          data['acknowledged']!,
          _acknowledgedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientEventId};
  @override
  PendingEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingEvent(
      clientEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_event_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site_id'],
      )!,
      siteName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site_name'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy'],
      ),
      isMocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_mocked'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      serverShiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_shift_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      acknowledged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}acknowledged'],
      )!,
    );
  }

  @override
  $PendingEventsTable createAlias(String alias) {
    return $PendingEventsTable(attachedDatabase, alias);
  }
}

class PendingEvent extends DataClass implements Insertable<PendingEvent> {
  final String clientEventId;
  final String userId;
  final String type;
  final String siteId;
  final String? siteName;
  final DateTime occurredAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool? isMocked;
  final String deviceId;
  final String status;
  final int attempts;
  final String? errorCode;
  final String? errorMessage;
  final String? serverShiftId;
  final DateTime createdAt;
  final DateTime? nextAttemptAt;
  final DateTime? syncedAt;
  final bool acknowledged;
  const PendingEvent({
    required this.clientEventId,
    required this.userId,
    required this.type,
    required this.siteId,
    this.siteName,
    required this.occurredAt,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.isMocked,
    required this.deviceId,
    required this.status,
    required this.attempts,
    this.errorCode,
    this.errorMessage,
    this.serverShiftId,
    required this.createdAt,
    this.nextAttemptAt,
    this.syncedAt,
    required this.acknowledged,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_event_id'] = Variable<String>(clientEventId);
    map['user_id'] = Variable<String>(userId);
    map['type'] = Variable<String>(type);
    map['site_id'] = Variable<String>(siteId);
    if (!nullToAbsent || siteName != null) {
      map['site_name'] = Variable<String>(siteName);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || accuracy != null) {
      map['accuracy'] = Variable<double>(accuracy);
    }
    if (!nullToAbsent || isMocked != null) {
      map['is_mocked'] = Variable<bool>(isMocked);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || serverShiftId != null) {
      map['server_shift_id'] = Variable<String>(serverShiftId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['acknowledged'] = Variable<bool>(acknowledged);
    return map;
  }

  PendingEventsCompanion toCompanion(bool nullToAbsent) {
    return PendingEventsCompanion(
      clientEventId: Value(clientEventId),
      userId: Value(userId),
      type: Value(type),
      siteId: Value(siteId),
      siteName: siteName == null && nullToAbsent
          ? const Value.absent()
          : Value(siteName),
      occurredAt: Value(occurredAt),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      accuracy: accuracy == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracy),
      isMocked: isMocked == null && nullToAbsent
          ? const Value.absent()
          : Value(isMocked),
      deviceId: Value(deviceId),
      status: Value(status),
      attempts: Value(attempts),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      serverShiftId: serverShiftId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverShiftId),
      createdAt: Value(createdAt),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      acknowledged: Value(acknowledged),
    );
  }

  factory PendingEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingEvent(
      clientEventId: serializer.fromJson<String>(json['clientEventId']),
      userId: serializer.fromJson<String>(json['userId']),
      type: serializer.fromJson<String>(json['type']),
      siteId: serializer.fromJson<String>(json['siteId']),
      siteName: serializer.fromJson<String?>(json['siteName']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      accuracy: serializer.fromJson<double?>(json['accuracy']),
      isMocked: serializer.fromJson<bool?>(json['isMocked']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      serverShiftId: serializer.fromJson<String?>(json['serverShiftId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      acknowledged: serializer.fromJson<bool>(json['acknowledged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientEventId': serializer.toJson<String>(clientEventId),
      'userId': serializer.toJson<String>(userId),
      'type': serializer.toJson<String>(type),
      'siteId': serializer.toJson<String>(siteId),
      'siteName': serializer.toJson<String?>(siteName),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'accuracy': serializer.toJson<double?>(accuracy),
      'isMocked': serializer.toJson<bool?>(isMocked),
      'deviceId': serializer.toJson<String>(deviceId),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'serverShiftId': serializer.toJson<String?>(serverShiftId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'acknowledged': serializer.toJson<bool>(acknowledged),
    };
  }

  PendingEvent copyWith({
    String? clientEventId,
    String? userId,
    String? type,
    String? siteId,
    Value<String?> siteName = const Value.absent(),
    DateTime? occurredAt,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<double?> accuracy = const Value.absent(),
    Value<bool?> isMocked = const Value.absent(),
    String? deviceId,
    String? status,
    int? attempts,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<String?> serverShiftId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    bool? acknowledged,
  }) => PendingEvent(
    clientEventId: clientEventId ?? this.clientEventId,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    siteId: siteId ?? this.siteId,
    siteName: siteName.present ? siteName.value : this.siteName,
    occurredAt: occurredAt ?? this.occurredAt,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    accuracy: accuracy.present ? accuracy.value : this.accuracy,
    isMocked: isMocked.present ? isMocked.value : this.isMocked,
    deviceId: deviceId ?? this.deviceId,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    serverShiftId: serverShiftId.present
        ? serverShiftId.value
        : this.serverShiftId,
    createdAt: createdAt ?? this.createdAt,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    acknowledged: acknowledged ?? this.acknowledged,
  );
  PendingEvent copyWithCompanion(PendingEventsCompanion data) {
    return PendingEvent(
      clientEventId: data.clientEventId.present
          ? data.clientEventId.value
          : this.clientEventId,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      siteName: data.siteName.present ? data.siteName.value : this.siteName,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      isMocked: data.isMocked.present ? data.isMocked.value : this.isMocked,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      serverShiftId: data.serverShiftId.present
          ? data.serverShiftId.value
          : this.serverShiftId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      acknowledged: data.acknowledged.present
          ? data.acknowledged.value
          : this.acknowledged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingEvent(')
          ..write('clientEventId: $clientEventId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('siteId: $siteId, ')
          ..write('siteName: $siteName, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('isMocked: $isMocked, ')
          ..write('deviceId: $deviceId, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('serverShiftId: $serverShiftId, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('acknowledged: $acknowledged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    clientEventId,
    userId,
    type,
    siteId,
    siteName,
    occurredAt,
    latitude,
    longitude,
    accuracy,
    isMocked,
    deviceId,
    status,
    attempts,
    errorCode,
    errorMessage,
    serverShiftId,
    createdAt,
    nextAttemptAt,
    syncedAt,
    acknowledged,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingEvent &&
          other.clientEventId == this.clientEventId &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.siteId == this.siteId &&
          other.siteName == this.siteName &&
          other.occurredAt == this.occurredAt &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.accuracy == this.accuracy &&
          other.isMocked == this.isMocked &&
          other.deviceId == this.deviceId &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.serverShiftId == this.serverShiftId &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.syncedAt == this.syncedAt &&
          other.acknowledged == this.acknowledged);
}

class PendingEventsCompanion extends UpdateCompanion<PendingEvent> {
  final Value<String> clientEventId;
  final Value<String> userId;
  final Value<String> type;
  final Value<String> siteId;
  final Value<String?> siteName;
  final Value<DateTime> occurredAt;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<double?> accuracy;
  final Value<bool?> isMocked;
  final Value<String> deviceId;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<String?> serverShiftId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> nextAttemptAt;
  final Value<DateTime?> syncedAt;
  final Value<bool> acknowledged;
  final Value<int> rowid;
  const PendingEventsCompanion({
    this.clientEventId = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.siteId = const Value.absent(),
    this.siteName = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.isMocked = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.serverShiftId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.acknowledged = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingEventsCompanion.insert({
    required String clientEventId,
    required String userId,
    required String type,
    required String siteId,
    this.siteName = const Value.absent(),
    required DateTime occurredAt,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.isMocked = const Value.absent(),
    required String deviceId,
    required String status,
    this.attempts = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.serverShiftId = const Value.absent(),
    required DateTime createdAt,
    this.nextAttemptAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.acknowledged = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clientEventId = Value(clientEventId),
       userId = Value(userId),
       type = Value(type),
       siteId = Value(siteId),
       occurredAt = Value(occurredAt),
       deviceId = Value(deviceId),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<PendingEvent> custom({
    Expression<String>? clientEventId,
    Expression<String>? userId,
    Expression<String>? type,
    Expression<String>? siteId,
    Expression<String>? siteName,
    Expression<DateTime>? occurredAt,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracy,
    Expression<bool>? isMocked,
    Expression<String>? deviceId,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<String>? serverShiftId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? syncedAt,
    Expression<bool>? acknowledged,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (siteId != null) 'site_id': siteId,
      if (siteName != null) 'site_name': siteName,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (isMocked != null) 'is_mocked': isMocked,
      if (deviceId != null) 'device_id': deviceId,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (serverShiftId != null) 'server_shift_id': serverShiftId,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (acknowledged != null) 'acknowledged': acknowledged,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingEventsCompanion copyWith({
    Value<String>? clientEventId,
    Value<String>? userId,
    Value<String>? type,
    Value<String>? siteId,
    Value<String?>? siteName,
    Value<DateTime>? occurredAt,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<double?>? accuracy,
    Value<bool?>? isMocked,
    Value<String>? deviceId,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<String?>? serverShiftId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? nextAttemptAt,
    Value<DateTime?>? syncedAt,
    Value<bool>? acknowledged,
    Value<int>? rowid,
  }) {
    return PendingEventsCompanion(
      clientEventId: clientEventId ?? this.clientEventId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      occurredAt: occurredAt ?? this.occurredAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      isMocked: isMocked ?? this.isMocked,
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      serverShiftId: serverShiftId ?? this.serverShiftId,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      syncedAt: syncedAt ?? this.syncedAt,
      acknowledged: acknowledged ?? this.acknowledged,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientEventId.present) {
      map['client_event_id'] = Variable<String>(clientEventId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<String>(siteId.value);
    }
    if (siteName.present) {
      map['site_name'] = Variable<String>(siteName.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (isMocked.present) {
      map['is_mocked'] = Variable<bool>(isMocked.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (serverShiftId.present) {
      map['server_shift_id'] = Variable<String>(serverShiftId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (acknowledged.present) {
      map['acknowledged'] = Variable<bool>(acknowledged.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingEventsCompanion(')
          ..write('clientEventId: $clientEventId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('siteId: $siteId, ')
          ..write('siteName: $siteName, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('isMocked: $isMocked, ')
          ..write('deviceId: $deviceId, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('serverShiftId: $serverShiftId, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('acknowledged: $acknowledged, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheEntriesTable extends CacheEntries
    with TableInfo<$CacheEntriesTable, CacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [key, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheEntry> instance, {
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
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheEntriesTable createAlias(String alias) {
    return $CacheEntriesTable(attachedDatabase, alias);
  }
}

class CacheEntry extends DataClass implements Insertable<CacheEntry> {
  final String key;
  final String json;
  final DateTime updatedAt;
  const CacheEntry({
    required this.key,
    required this.json,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheEntriesCompanion(
      key: Value(key),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheEntry(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheEntry copyWith({String? key, String? json, DateTime? updatedAt}) =>
      CacheEntry(
        key: key ?? this.key,
        json: json ?? this.json,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CacheEntry copyWithCompanion(CacheEntriesCompanion data) {
    return CacheEntry(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntry(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheEntry &&
          other.key == this.key &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class CacheEntriesCompanion extends UpdateCompanion<CacheEntry> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheEntriesCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheEntriesCompanion.insert({
    required String key,
    required String json,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<CacheEntry> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheEntriesCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntriesCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PendingEventsTable pendingEvents = $PendingEventsTable(this);
  late final $CacheEntriesTable cacheEntries = $CacheEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pendingEvents,
    cacheEntries,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$PendingEventsTableCreateCompanionBuilder =
    PendingEventsCompanion Function({
      required String clientEventId,
      required String userId,
      required String type,
      required String siteId,
      Value<String?> siteName,
      required DateTime occurredAt,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> accuracy,
      Value<bool?> isMocked,
      required String deviceId,
      required String status,
      Value<int> attempts,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<String?> serverShiftId,
      required DateTime createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<DateTime?> syncedAt,
      Value<bool> acknowledged,
      Value<int> rowid,
    });
typedef $$PendingEventsTableUpdateCompanionBuilder =
    PendingEventsCompanion Function({
      Value<String> clientEventId,
      Value<String> userId,
      Value<String> type,
      Value<String> siteId,
      Value<String?> siteName,
      Value<DateTime> occurredAt,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> accuracy,
      Value<bool?> isMocked,
      Value<String> deviceId,
      Value<String> status,
      Value<int> attempts,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<String?> serverShiftId,
      Value<DateTime> createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<DateTime?> syncedAt,
      Value<bool> acknowledged,
      Value<int> rowid,
    });

class $$PendingEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingEventsTable> {
  $$PendingEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siteId => $composableBuilder(
    column: $table.siteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siteName => $composableBuilder(
    column: $table.siteName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
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

  ColumnFilters<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMocked => $composableBuilder(
    column: $table.isMocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverShiftId => $composableBuilder(
    column: $table.serverShiftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingEventsTable> {
  $$PendingEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siteId => $composableBuilder(
    column: $table.siteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siteName => $composableBuilder(
    column: $table.siteName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
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

  ColumnOrderings<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMocked => $composableBuilder(
    column: $table.isMocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverShiftId => $composableBuilder(
    column: $table.serverShiftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingEventsTable> {
  $$PendingEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get siteId =>
      $composableBuilder(column: $table.siteId, builder: (column) => column);

  GeneratedColumn<String> get siteName =>
      $composableBuilder(column: $table.siteName, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<bool> get isMocked =>
      $composableBuilder(column: $table.isMocked, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverShiftId => $composableBuilder(
    column: $table.serverShiftId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => column,
  );
}

class $$PendingEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingEventsTable,
          PendingEvent,
          $$PendingEventsTableFilterComposer,
          $$PendingEventsTableOrderingComposer,
          $$PendingEventsTableAnnotationComposer,
          $$PendingEventsTableCreateCompanionBuilder,
          $$PendingEventsTableUpdateCompanionBuilder,
          (
            PendingEvent,
            BaseReferences<_$AppDatabase, $PendingEventsTable, PendingEvent>,
          ),
          PendingEvent,
          PrefetchHooks Function()
        > {
  $$PendingEventsTableTableManager(_$AppDatabase db, $PendingEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clientEventId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> siteId = const Value.absent(),
                Value<String?> siteName = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> accuracy = const Value.absent(),
                Value<bool?> isMocked = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> serverShiftId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<bool> acknowledged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingEventsCompanion(
                clientEventId: clientEventId,
                userId: userId,
                type: type,
                siteId: siteId,
                siteName: siteName,
                occurredAt: occurredAt,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                isMocked: isMocked,
                deviceId: deviceId,
                status: status,
                attempts: attempts,
                errorCode: errorCode,
                errorMessage: errorMessage,
                serverShiftId: serverShiftId,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                syncedAt: syncedAt,
                acknowledged: acknowledged,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientEventId,
                required String userId,
                required String type,
                required String siteId,
                Value<String?> siteName = const Value.absent(),
                required DateTime occurredAt,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> accuracy = const Value.absent(),
                Value<bool?> isMocked = const Value.absent(),
                required String deviceId,
                required String status,
                Value<int> attempts = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> serverShiftId = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<bool> acknowledged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingEventsCompanion.insert(
                clientEventId: clientEventId,
                userId: userId,
                type: type,
                siteId: siteId,
                siteName: siteName,
                occurredAt: occurredAt,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                isMocked: isMocked,
                deviceId: deviceId,
                status: status,
                attempts: attempts,
                errorCode: errorCode,
                errorMessage: errorMessage,
                serverShiftId: serverShiftId,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                syncedAt: syncedAt,
                acknowledged: acknowledged,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingEventsTable, PendingEvent>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingEventsTable,
                    PendingEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingEventsTable,
      PendingEvent,
      $$PendingEventsTableFilterComposer,
      $$PendingEventsTableOrderingComposer,
      $$PendingEventsTableAnnotationComposer,
      $$PendingEventsTableCreateCompanionBuilder,
      $$PendingEventsTableUpdateCompanionBuilder,
      (
        PendingEvent,
        BaseReferences<_$AppDatabase, $PendingEventsTable, PendingEvent>,
      ),
      PendingEvent,
      PrefetchHooks Function()
    >;
typedef $$CacheEntriesTableCreateCompanionBuilder =
    CacheEntriesCompanion Function({
      required String key,
      required String json,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CacheEntriesTableUpdateCompanionBuilder =
    CacheEntriesCompanion Function({
      Value<String> key,
      Value<String> json,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableFilterComposer({
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

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheEntriesTable,
          CacheEntry,
          $$CacheEntriesTableFilterComposer,
          $$CacheEntriesTableOrderingComposer,
          $$CacheEntriesTableAnnotationComposer,
          $$CacheEntriesTableCreateCompanionBuilder,
          $$CacheEntriesTableUpdateCompanionBuilder,
          (
            CacheEntry,
            BaseReferences<_$AppDatabase, $CacheEntriesTable, CacheEntry>,
          ),
          CacheEntry,
          PrefetchHooks Function()
        > {
  $$CacheEntriesTableTableManager(_$AppDatabase db, $CacheEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion(
                key: key,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String json,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion.insert(
                key: key,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheEntriesTable, CacheEntry>(table),
                  BaseReferences<_$AppDatabase, $CacheEntriesTable, CacheEntry>(
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

typedef $$CacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheEntriesTable,
      CacheEntry,
      $$CacheEntriesTableFilterComposer,
      $$CacheEntriesTableOrderingComposer,
      $$CacheEntriesTableAnnotationComposer,
      $$CacheEntriesTableCreateCompanionBuilder,
      $$CacheEntriesTableUpdateCompanionBuilder,
      (
        CacheEntry,
        BaseReferences<_$AppDatabase, $CacheEntriesTable, CacheEntry>,
      ),
      CacheEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PendingEventsTableTableManager get pendingEvents =>
      $$PendingEventsTableTableManager(_db, _db.pendingEvents);
  $$CacheEntriesTableTableManager get cacheEntries =>
      $$CacheEntriesTableTableManager(_db, _db.cacheEntries);
}
