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

class PeerConsents extends Table {
  TextColumn get peerAtsign => text()();
  TextColumn get status => text().withDefault(const Constant('none'))();
  TextColumn get lastUpdated => text()();
  BoolColumn get outboundPermitted => boolean().withDefault(const Constant(true))();
  TextColumn get displayName => text().nullable()();

  @override
  Set<Column> get primaryKey => {peerAtsign};
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
@DriftDatabase(tables: [Coordinates, PeerConsents])
class LocalDb extends _$LocalDb {
  LocalDb._(String atSign) : super(_openConnection(atSign));

  static LocalDb? _instance;

  /// Singleton accessor. The database must be initialized first.
  static LocalDb get instance {
    if (_instance == null) {
      throw StateError('LocalDb has not been initialized. Call init(atSign) first.');
    }
    return _instance!;
  }

  /// Initializes the database scoped to a specific atSign.
  static void init(String atSign) {
    if (_instance != null) {
      _instance!.close();
    }
    _instance = LocalDb._(atSign);
  }

  /// Closes the current database instance.
  static Future<void> closeInstance() async {
    await _instance?.close();
    _instance = null;
  }

  @override
  int get schemaVersion => 4;

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
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(peerConsents);
        }
        if (from < 3) {
          // Recreate the peerConsents table to safely drop the expiresAt column
          // and add the new outboundPermitted column.
          await m.deleteTable('peer_consents');
          await m.createTable(peerConsents);
        }
        if (from < 4) {
          await m.addColumn(peerConsents, peerConsents.displayName);
        }
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

  // evictExpiredConsents removed as duration is now infinite

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

  // ── Peer Consent Operations ────────────────────────────────────────────────

  /// Updates or inserts a peer's consent status.
  Future<int> updateConsentStatus(String peerAtSign, String status, {bool? outboundPermitted, String? displayName}) {
    return into(peerConsents).insertOnConflictUpdate(
      PeerConsentsCompanion.insert(
        peerAtsign: peerAtSign,
        status: Value(status),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
        outboundPermitted: outboundPermitted != null ? Value(outboundPermitted) : const Value.absent(),
        displayName: displayName != null ? Value(displayName) : const Value.absent(),
      ),
    );
  }

  /// Gets the current consent status of a peer.
  Future<String> getConsentStatus(String peerAtSign) async {
    final query = select(peerConsents)..where((c) => c.peerAtsign.equals(peerAtSign));
    final result = await query.getSingleOrNull();
    return result?.status ?? 'none';
  }

  /// Returns a reactive stream of all peer consent records.
  Stream<List<PeerConsent>> watchConsents() {
    return select(peerConsents).watch();
  }
}

/// Opens the SQLite database connection for the desktop platform.
///
/// The database file is stored in the application support directory
/// under `AtNav/{atSign}/telemetry.db`.
LazyDatabase _openConnection(String atSign) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final safeAtSign = atSign.replaceAll('@', '');
    final dbPath = p.join(dir.path, 'AtNav', safeAtSign, 'telemetry.db');
    final dbDir = Directory(p.dirname(dbPath));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final file = File(dbPath);
    return NativeDatabase.createInBackground(file);
  });
}
