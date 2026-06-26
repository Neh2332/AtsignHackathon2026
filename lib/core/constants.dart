/// AtNav application-wide constants.
///
/// All protocol-level and telemetry configuration values are centralized here
/// to enforce consistency across the publisher, subscriber, and storage layers.
library;

class AppConstants {
  AppConstants._();

  // ── Atsign Protocol ──────────────────────────────────────────────────────
  /// Application namespace scoping all atKeys to this app.
  /// Wire shape: `@recipient:location.AtNav@owner`
  static const String appNamespace = 'atnav';

  /// Root directory server address for atSign → host:port lookup.
  static const String rootDomain = 'root.atsign.org';

  /// Root directory server port.
  static const int rootPort = 64;

  // ── Telemetry Configuration ──────────────────────────────────────────────
  /// Interval between location telemetry broadcasts (seconds).
  static const int telemetryIntervalSeconds = 5;

  /// Notification Time-To-Live in milliseconds.
  /// Ephemeral notifications bypass the server-side commit log when ttln is set.
  /// Capped at 60 seconds to prevent stale coordinate accumulation.
  static const int notificationTtlnMs = 60000;

  /// Key name used for location telemetry notifications.
  static const String locationKeyName = 'location';

  /// Fully qualified key with namespace: `location.AtNav`
  static const String locationKeyFull = '$locationKeyName.$appNamespace';

  /// Key name used for mutual consent handshake notifications.
  static const String consentKeyName = 'mutual_consent';

  // ── Local Storage & Eviction ─────────────────────────────────────────────
  /// Maximum age (hours) for locally cached coordinate trails.
  /// Records older than this are automatically purged by the eviction loop.
  static const int trailRetentionHours = 24;

  /// Maximum number of trail points retained per peer for polyline rendering.
  static const int maxTrailPoints = 500;

  /// Eviction loop interval in minutes.
  static const int evictionIntervalMinutes = 10;

  // ── UI Configuration ─────────────────────────────────────────────────────
  /// Default map zoom level.
  static const double defaultMapZoom = 13.0;

  /// Minimum desktop window width.
  static const double minWindowWidth = 1024;

  /// Minimum desktop window height.
  static const double minWindowHeight = 768;

  /// Initial desktop window width.
  static const double initialWindowWidth = 1440;

  /// Initial desktop window height.
  static const double initialWindowHeight = 900;

  /// Left sidebar width ratio (peer panel).
  static const double sidebarWidthRatio = 0.30;

  // ── Coordinate Display ───────────────────────────────────────────────────
  /// Decimal precision for displaying latitude/longitude.
  static const int coordinatePrecision = 6;
}
