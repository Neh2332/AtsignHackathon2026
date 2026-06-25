// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $CoordinatesTable extends Coordinates
    with TableInfo<$CoordinatesTable, Coordinate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoordinatesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _peerAtsignMeta = const VerificationMeta(
    'peerAtsign',
  );
  @override
  late final GeneratedColumn<String> peerAtsign = GeneratedColumn<String>(
    'peer_atsign',
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
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<String> timestamp = GeneratedColumn<String>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<String> receivedAt = GeneratedColumn<String>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    peerAtsign,
    latitude,
    longitude,
    accuracy,
    timestamp,
    receivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coordinates';
  @override
  VerificationContext validateIntegrity(
    Insertable<Coordinate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('peer_atsign')) {
      context.handle(
        _peerAtsignMeta,
        peerAtsign.isAcceptableOrUnknown(data['peer_atsign']!, _peerAtsignMeta),
      );
    } else if (isInserting) {
      context.missing(_peerAtsignMeta);
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
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Coordinate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Coordinate(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      peerAtsign:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}peer_atsign'],
          )!,
      latitude:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}latitude'],
          )!,
      longitude:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}longitude'],
          )!,
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy'],
      ),
      timestamp:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}timestamp'],
          )!,
      receivedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}received_at'],
          )!,
    );
  }

  @override
  $CoordinatesTable createAlias(String alias) {
    return $CoordinatesTable(attachedDatabase, alias);
  }
}

class Coordinate extends DataClass implements Insertable<Coordinate> {
  final int id;
  final String peerAtsign;
  final double latitude;
  final double longitude;
  final double? accuracy;

  /// ISO-8601 UTC timestamp from the sender's device.
  final String timestamp;

  /// ISO-8601 UTC timestamp of local receipt.
  final String receivedAt;
  const Coordinate({
    required this.id,
    required this.peerAtsign,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
    required this.receivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['peer_atsign'] = Variable<String>(peerAtsign);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || accuracy != null) {
      map['accuracy'] = Variable<double>(accuracy);
    }
    map['timestamp'] = Variable<String>(timestamp);
    map['received_at'] = Variable<String>(receivedAt);
    return map;
  }

  CoordinatesCompanion toCompanion(bool nullToAbsent) {
    return CoordinatesCompanion(
      id: Value(id),
      peerAtsign: Value(peerAtsign),
      latitude: Value(latitude),
      longitude: Value(longitude),
      accuracy:
          accuracy == null && nullToAbsent
              ? const Value.absent()
              : Value(accuracy),
      timestamp: Value(timestamp),
      receivedAt: Value(receivedAt),
    );
  }

  factory Coordinate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Coordinate(
      id: serializer.fromJson<int>(json['id']),
      peerAtsign: serializer.fromJson<String>(json['peerAtsign']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      accuracy: serializer.fromJson<double?>(json['accuracy']),
      timestamp: serializer.fromJson<String>(json['timestamp']),
      receivedAt: serializer.fromJson<String>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'peerAtsign': serializer.toJson<String>(peerAtsign),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'accuracy': serializer.toJson<double?>(accuracy),
      'timestamp': serializer.toJson<String>(timestamp),
      'receivedAt': serializer.toJson<String>(receivedAt),
    };
  }

  Coordinate copyWith({
    int? id,
    String? peerAtsign,
    double? latitude,
    double? longitude,
    Value<double?> accuracy = const Value.absent(),
    String? timestamp,
    String? receivedAt,
  }) => Coordinate(
    id: id ?? this.id,
    peerAtsign: peerAtsign ?? this.peerAtsign,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    accuracy: accuracy.present ? accuracy.value : this.accuracy,
    timestamp: timestamp ?? this.timestamp,
    receivedAt: receivedAt ?? this.receivedAt,
  );
  Coordinate copyWithCompanion(CoordinatesCompanion data) {
    return Coordinate(
      id: data.id.present ? data.id.value : this.id,
      peerAtsign:
          data.peerAtsign.present ? data.peerAtsign.value : this.peerAtsign,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Coordinate(')
          ..write('id: $id, ')
          ..write('peerAtsign: $peerAtsign, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('timestamp: $timestamp, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    peerAtsign,
    latitude,
    longitude,
    accuracy,
    timestamp,
    receivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Coordinate &&
          other.id == this.id &&
          other.peerAtsign == this.peerAtsign &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.accuracy == this.accuracy &&
          other.timestamp == this.timestamp &&
          other.receivedAt == this.receivedAt);
}

class CoordinatesCompanion extends UpdateCompanion<Coordinate> {
  final Value<int> id;
  final Value<String> peerAtsign;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> accuracy;
  final Value<String> timestamp;
  final Value<String> receivedAt;
  const CoordinatesCompanion({
    this.id = const Value.absent(),
    this.peerAtsign = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.receivedAt = const Value.absent(),
  });
  CoordinatesCompanion.insert({
    this.id = const Value.absent(),
    required String peerAtsign,
    required double latitude,
    required double longitude,
    this.accuracy = const Value.absent(),
    required String timestamp,
    required String receivedAt,
  }) : peerAtsign = Value(peerAtsign),
       latitude = Value(latitude),
       longitude = Value(longitude),
       timestamp = Value(timestamp),
       receivedAt = Value(receivedAt);
  static Insertable<Coordinate> custom({
    Expression<int>? id,
    Expression<String>? peerAtsign,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracy,
    Expression<String>? timestamp,
    Expression<String>? receivedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerAtsign != null) 'peer_atsign': peerAtsign,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (timestamp != null) 'timestamp': timestamp,
      if (receivedAt != null) 'received_at': receivedAt,
    });
  }

  CoordinatesCompanion copyWith({
    Value<int>? id,
    Value<String>? peerAtsign,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double?>? accuracy,
    Value<String>? timestamp,
    Value<String>? receivedAt,
  }) {
    return CoordinatesCompanion(
      id: id ?? this.id,
      peerAtsign: peerAtsign ?? this.peerAtsign,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (peerAtsign.present) {
      map['peer_atsign'] = Variable<String>(peerAtsign.value);
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
    if (timestamp.present) {
      map['timestamp'] = Variable<String>(timestamp.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<String>(receivedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoordinatesCompanion(')
          ..write('id: $id, ')
          ..write('peerAtsign: $peerAtsign, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('timestamp: $timestamp, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDb extends GeneratedDatabase {
  _$LocalDb(QueryExecutor e) : super(e);
  $LocalDbManager get managers => $LocalDbManager(this);
  late final $CoordinatesTable coordinates = $CoordinatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [coordinates];
}

typedef $$CoordinatesTableCreateCompanionBuilder =
    CoordinatesCompanion Function({
      Value<int> id,
      required String peerAtsign,
      required double latitude,
      required double longitude,
      Value<double?> accuracy,
      required String timestamp,
      required String receivedAt,
    });
typedef $$CoordinatesTableUpdateCompanionBuilder =
    CoordinatesCompanion Function({
      Value<int> id,
      Value<String> peerAtsign,
      Value<double> latitude,
      Value<double> longitude,
      Value<double?> accuracy,
      Value<String> timestamp,
      Value<String> receivedAt,
    });

class $$CoordinatesTableFilterComposer
    extends Composer<_$LocalDb, $CoordinatesTable> {
  $$CoordinatesTableFilterComposer({
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

  ColumnFilters<String> get peerAtsign => $composableBuilder(
    column: $table.peerAtsign,
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

  ColumnFilters<String> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoordinatesTableOrderingComposer
    extends Composer<_$LocalDb, $CoordinatesTable> {
  $$CoordinatesTableOrderingComposer({
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

  ColumnOrderings<String> get peerAtsign => $composableBuilder(
    column: $table.peerAtsign,
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

  ColumnOrderings<String> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoordinatesTableAnnotationComposer
    extends Composer<_$LocalDb, $CoordinatesTable> {
  $$CoordinatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get peerAtsign => $composableBuilder(
    column: $table.peerAtsign,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<String> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );
}

class $$CoordinatesTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $CoordinatesTable,
          Coordinate,
          $$CoordinatesTableFilterComposer,
          $$CoordinatesTableOrderingComposer,
          $$CoordinatesTableAnnotationComposer,
          $$CoordinatesTableCreateCompanionBuilder,
          $$CoordinatesTableUpdateCompanionBuilder,
          (
            Coordinate,
            BaseReferences<_$LocalDb, $CoordinatesTable, Coordinate>,
          ),
          Coordinate,
          PrefetchHooks Function()
        > {
  $$CoordinatesTableTableManager(_$LocalDb db, $CoordinatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CoordinatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CoordinatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$CoordinatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> peerAtsign = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double?> accuracy = const Value.absent(),
                Value<String> timestamp = const Value.absent(),
                Value<String> receivedAt = const Value.absent(),
              }) => CoordinatesCompanion(
                id: id,
                peerAtsign: peerAtsign,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                timestamp: timestamp,
                receivedAt: receivedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String peerAtsign,
                required double latitude,
                required double longitude,
                Value<double?> accuracy = const Value.absent(),
                required String timestamp,
                required String receivedAt,
              }) => CoordinatesCompanion.insert(
                id: id,
                peerAtsign: peerAtsign,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                timestamp: timestamp,
                receivedAt: receivedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoordinatesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $CoordinatesTable,
      Coordinate,
      $$CoordinatesTableFilterComposer,
      $$CoordinatesTableOrderingComposer,
      $$CoordinatesTableAnnotationComposer,
      $$CoordinatesTableCreateCompanionBuilder,
      $$CoordinatesTableUpdateCompanionBuilder,
      (Coordinate, BaseReferences<_$LocalDb, $CoordinatesTable, Coordinate>),
      Coordinate,
      PrefetchHooks Function()
    >;

class $LocalDbManager {
  final _$LocalDb _db;
  $LocalDbManager(this._db);
  $$CoordinatesTableTableManager get coordinates =>
      $$CoordinatesTableTableManager(_db, _db.coordinates);
}
