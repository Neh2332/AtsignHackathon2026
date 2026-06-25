import 'dart:convert';

/// Immutable data class representing a single location telemetry observation.
///
/// Instances are created by the [TelemetryStreamer] on the sender side,
/// serialized to JSON for E2E encrypted transmission via the Atsign Protocol,
/// and deserialized by the [TelemetryListener] on the receiver side before
/// insertion into the local SQLite database.
class TelemetryPoint {
  /// The atSign of the peer who generated this coordinate.
  final String peerAtSign;

  /// WGS-84 latitude in decimal degrees.
  final double latitude;

  /// WGS-84 longitude in decimal degrees.
  final double longitude;

  /// Estimated horizontal accuracy in meters (optional, platform-dependent).
  final double? accuracy;

  /// UTC timestamp when the coordinate was captured on the sender's device.
  final DateTime timestamp;

  /// UTC timestamp when the coordinate was received on this device.
  final DateTime receivedAt;

  const TelemetryPoint({
    required this.peerAtSign,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
    required this.receivedAt,
  });

  /// Constructs a [TelemetryPoint] from the decrypted JSON payload transmitted
  /// via the Atsign notification pipeline.
  ///
  /// The [peerAtSign] is extracted from the notification metadata (the sender's
  /// atSign), not from the JSON body itself, to prevent spoofing.
  factory TelemetryPoint.fromNotificationJson(
    String jsonString,
    String peerAtSign,
  ) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return TelemetryPoint(
      peerAtSign: peerAtSign,
      latitude: (data['lat'] as num).toDouble(),
      longitude: (data['lng'] as num).toDouble(),
      accuracy: data['acc'] != null ? (data['acc'] as num).toDouble() : null,
      timestamp: DateTime.parse(data['ts'] as String),
      receivedAt: DateTime.now().toUtc(),
    );
  }

  /// Constructs a [TelemetryPoint] from a database row map.
  factory TelemetryPoint.fromDbRow(Map<String, dynamic> row) {
    return TelemetryPoint(
      peerAtSign: row['peer_atsign'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      accuracy:
          row['accuracy'] != null
              ? (row['accuracy'] as num).toDouble()
              : null,
      timestamp: DateTime.parse(row['timestamp'] as String),
      receivedAt: DateTime.parse(row['received_at'] as String),
    );
  }

  /// Serializes the coordinate payload for E2E encrypted transmission.
  ///
  /// The wire format is intentionally compact to minimize notification payload
  /// size. Keys are abbreviated: `lat`, `lng`, `acc`, `ts`.
  /// The [peerAtSign] is NOT included in the JSON body — it is derived from
  /// the notification metadata on the receiver side.
  String toTransmissionJson() {
    final Map<String, dynamic> payload = {
      'lat': latitude,
      'lng': longitude,
      'ts': timestamp.toUtc().toIso8601String(),
    };
    if (accuracy != null) {
      payload['acc'] = accuracy;
    }
    return jsonEncode(payload);
  }

  /// Converts to a map suitable for SQLite insertion.
  Map<String, dynamic> toDbRow() {
    return {
      'peer_atsign': peerAtSign,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'received_at': receivedAt.toUtc().toIso8601String(),
    };
  }

  /// Returns the age of this coordinate relative to the current time.
  Duration get age => DateTime.now().toUtc().difference(timestamp);

  /// Returns `true` if this coordinate is older than [maxAge].
  bool isExpired(Duration maxAge) => age > maxAge;

  @override
  String toString() {
    return 'TelemetryPoint('
        'peer=$peerAtSign, '
        'lat=${latitude.toStringAsFixed(6)}, '
        'lng=${longitude.toStringAsFixed(6)}, '
        'ts=${timestamp.toIso8601String()}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TelemetryPoint &&
        other.peerAtSign == peerAtSign &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(peerAtSign, latitude, longitude, timestamp);

  /// Creates a copy with optional field overrides.
  TelemetryPoint copyWith({
    String? peerAtSign,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    DateTime? receivedAt,
  }) {
    return TelemetryPoint(
      peerAtSign: peerAtSign ?? this.peerAtSign,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }
}
