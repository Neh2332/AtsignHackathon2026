import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import '../../core/constants.dart';
import '../../models/telemetry_point.dart';

part 'local_db.g.dart';

/// Drift table definition for coordinate storage.
///
/// Each row represents a single telemetry observation from a peer atSign,
/// decrypted and persisted locally by the [TelemetryListener].
class Coordinates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get peerAtsign => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real().nullable()();

  /// ISO-8601 UTC timestamp from the sender's device.
  TextColumn get timestamp => text()();

  /// ISO-8601 UTC timestamp of local receipt.
  TextColumn get receivedAt => text()();
}

/// SQLite database manager for local telemetry coordinate storage.
///
/// This database is the bridge between the Atsign notification pipeline
/// and the reactive UI layer. The [TelemetryListener] writes decrypted
/// coordinates here, and the [MapScreen] reads them via reactive streams.
///
/// Design rationale (per Atsign SDK guidance):
/// High-frequency telemetry data (coordinates every 5 seconds) must NOT
/// be stored via AtCollection (which uses the server commit log).
/// Instead, we use short-TTL ephemeral notifications (ttln=60s) that
/// bypass the server commit log entirely, and persist observations
/// strictly in this local SQLite database.
@DriftDatabase(tables: [Coordinates])
class LocalDb extends _$LocalDb {
  LocalDb._() : super(_openConnection());

  static LocalDb? _instance;

  /// Singleton accessor. The database is opened once and reused.
  static LocalDb get instance {
    _instance ??= LocalDb._();
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create index for efficient peer + timestamp queries
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_peer_ts '
          'ON coordinates(peer_atsign, timestamp DESC)',
        );
      },
    );
  }

  Timer? _evictionTimer;

  /// Starts the automatic eviction loop that purges expired coordinates.
  ///
  /// Records older than [AppConstants.trailRetentionHours] are removed
  /// every [AppConstants.evictionIntervalMinutes] minutes.
  void startEvictionLoop() {
    _evictionTimer?.cancel();
    _evictionTimer = Timer.periodic(
      Duration(minutes: AppConstants.evictionIntervalMinutes),
      (_) => evictExpired(),
    );
    // Run once immediately on startup
    evictExpired();
  }

  /// Stops the automatic eviction loop.
  void stopEvictionLoop() {
    _evictionTimer?.cancel();
    _evictionTimer = null;
  }

  // ── Write Operations ─────────────────────────────────────────────────────

  /// Inserts a single telemetry coordinate into the local database.
  ///
  /// This is called by [TelemetryListener] after decrypting an inbound
  /// notification. The insert is non-blocking — it returns a [Future]
  /// that completes after the SQLite write commits.
  Future<int> insertCoordinate(TelemetryPoint point) {
    return into(coordinates).insert(
      CoordinatesCompanion.insert(
        peerAtsign: point.peerAtSign,
        latitude: point.latitude,
        longitude: point.longitude,
        accuracy: Value(point.accuracy),
        timestamp: point.timestamp.toUtc().toIso8601String(),
        receivedAt: point.receivedAt.toUtc().toIso8601String(),
      ),
    );
  }

  /// Purges all coordinate records older than the configured retention period.
  ///
  /// Called automatically by the eviction loop and can be invoked manually.
  Future<int> evictExpired() async {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(Duration(hours: AppConstants.trailRetentionHours))
        .toIso8601String();

    return (delete(coordinates)
          ..where((c) => c.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Deletes all coordinates for a specific peer.
  Future<int> deleteCoordinatesForPeer(String peerAtSign) {
    return (delete(coordinates)
          ..where((c) => c.peerAtsign.equals(peerAtSign)))
        .go();
  }

  /// Deletes all coordinate records from the database.
  Future<int> deleteAllCoordinates() {
    return delete(coordinates).go();
  }

  // ── Read Operations ──────────────────────────────────────────────────────

  /// Returns a reactive stream of the latest coordinate for each tracked peer.
  ///
  /// This is the primary data source for rendering live map pins.
  /// The stream emits a new [Map] whenever any peer's latest coordinate
  /// changes (insert or delete).
  Stream<Map<String, TelemetryPoint>> watchLatestByPeer() {
    final query = customSelect(
      'SELECT * FROM coordinates c1 '
      'WHERE c1.timestamp = ('
      '  SELECT MAX(c2.timestamp) FROM coordinates c2 '
      '  WHERE c2.peer_atsign = c1.peer_atsign'
      ') '
      'GROUP BY c1.peer_atsign '
      'ORDER BY c1.timestamp DESC',
      readsFrom: {coordinates},
    );

    return query.watch().map((rows) {
      final Map<String, TelemetryPoint> result = {};
      for (final row in rows) {
        final point = TelemetryPoint(
          peerAtSign: row.read<String>('peer_atsign'),
          latitude: row.read<double>('latitude'),
          longitude: row.read<double>('longitude'),
          accuracy: row.readNullable<double>('accuracy'),
          timestamp: DateTime.parse(row.read<String>('timestamp')),
          receivedAt: DateTime.parse(row.read<String>('received_at')),
        );
        result[point.peerAtSign] = point;
      }
      return result;
    });
  }

  /// Returns the coordinate trail (history) for a specific peer.
  ///
  /// Results are ordered by timestamp descending (newest first).
  /// Used for rendering polyline trails on the map.
  Future<List<TelemetryPoint>> getTrail(
    String peerAtSign, {
    int limit = 100,
  }) async {
    final query = select(coordinates)
      ..where((c) => c.peerAtsign.equals(peerAtSign))
      ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
      ..limit(limit);

    final rows = await query.get();
    return rows
        .map(
          (row) => TelemetryPoint(
            peerAtSign: row.peerAtsign,
            latitude: row.latitude,
            longitude: row.longitude,
            accuracy: row.accuracy,
            timestamp: DateTime.parse(row.timestamp),
            receivedAt: DateTime.parse(row.receivedAt),
          ),
        )
        .toList();
  }

  /// Returns coordinates within a specific time range for a peer.
  ///
  /// Used for time-range bucketing and historical analysis.
  Future<List<TelemetryPoint>> getTimeRange(
    String peerAtSign,
    DateTime from,
    DateTime to,
  ) async {
    final fromStr = from.toUtc().toIso8601String();
    final toStr = to.toUtc().toIso8601String();

    final query = select(coordinates)
      ..where(
        (c) =>
            c.peerAtsign.equals(peerAtSign) &
            c.timestamp.isBiggerOrEqualValue(fromStr) &
            c.timestamp.isSmallerOrEqualValue(toStr),
      )
      ..orderBy([(c) => OrderingTerm.asc(c.timestamp)]);

    final rows = await query.get();
    return rows
        .map(
          (row) => TelemetryPoint(
            peerAtSign: row.peerAtsign,
            latitude: row.latitude,
            longitude: row.longitude,
            accuracy: row.accuracy,
            timestamp: DateTime.parse(row.timestamp),
            receivedAt: DateTime.parse(row.receivedAt),
          ),
        )
        .toList();
  }

  /// Returns a reactive stream of all coordinates for a specific peer,
  /// limited to the most recent [limit] entries.
  ///
  /// Used by the UI to reactively update polyline trails without polling.
  Stream<List<TelemetryPoint>> watchTrail(
    String peerAtSign, {
    int limit = 100,
  }) {
    final query = select(coordinates)
      ..where((c) => c.peerAtsign.equals(peerAtSign))
      ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
      ..limit(limit);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => TelemetryPoint(
                  peerAtSign: row.peerAtsign,
                  latitude: row.latitude,
                  longitude: row.longitude,
                  accuracy: row.accuracy,
                  timestamp: DateTime.parse(row.timestamp),
                  receivedAt: DateTime.parse(row.receivedAt),
                ),
              )
              .toList(),
        );
  }

  /// Returns a distinct list of all peer atSigns that have at least one
  /// coordinate record in the database.
  Future<List<String>> getTrackedPeers() async {
    final query = customSelect(
      'SELECT DISTINCT peer_atsign FROM coordinates ORDER BY peer_atsign',
      readsFrom: {coordinates},
    );
    final rows = await query.get();
    return rows.map((r) => r.read<String>('peer_atsign')).toList();
  }

  /// Returns the total count of coordinate records in the database.
  Future<int> getCoordinateCount() async {
    final count = countAll();
    final query = selectOnly(coordinates)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}

/// Opens the SQLite database connection for the desktop platform.
///
/// The database file is stored in the application support directory
/// under `AtNav/telemetry.db`.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'AtNav', 'telemetry.db');
    final dbDir = Directory(p.dirname(dbPath));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final file = File(dbPath);
    return NativeDatabase.createInBackground(file);
  });
}
