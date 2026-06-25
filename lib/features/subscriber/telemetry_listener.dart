import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:flutter/foundation.dart';

import '../../core/at_service.dart';
import '../../core/constants.dart';
import '../../models/telemetry_point.dart';
import '../storage/local_db.dart';

/// The subscriber pipeline for inbound location telemetry.
///
/// Responsible for:
/// 1. Opening a multiplexed monitor socket filtered to the `.AtNav` namespace
/// 2. Subscribing to inbound notifications via [NotificationService.subscribe]
/// 3. Decrypting payloads (handled transparently by the SDK)
/// 4. Parsing JSON → [TelemetryPoint] domain objects
/// 5. Persisting to the local SQLite database via [LocalDb]
/// 6. Emitting on a [Stream] for real-time UI binding
///
/// Design rationale:
/// The monitor stream is the Atsign Protocol's real-time pub/sub channel.
/// When `atServerA` sends a `notify` to `atServerB`, the receiver's monitor
/// connection pushes the notification as a JSON payload over a persistent
/// TCP socket. The SDK's [NotificationService.subscribe] abstracts this
/// into a typed Dart [Stream].
class TelemetryListener extends ChangeNotifier {
  final AtService _atService;
  final LocalDb _localDb;

  StreamSubscription<AtNotification>? _notificationSubscription;
  final StreamController<TelemetryPoint> _pointController =
      StreamController<TelemetryPoint>.broadcast();

  bool _isListening = false;
  int _receivedCount = 0;
  TelemetryPoint? _lastReceivedPoint;
  String? _lastError;

  TelemetryListener(this._atService, this._localDb);

  // ── Public Getters ─────────────────────────────────────────────────────────

  /// Whether the listener is actively monitoring for inbound telemetry.
  bool get isListening => _isListening;

  /// Total number of telemetry points received since the listener started.
  int get receivedCount => _receivedCount;

  /// The most recently received telemetry point.
  TelemetryPoint? get lastReceivedPoint => _lastReceivedPoint;

  /// The last error encountered during listening.
  String? get lastError => _lastError;

  /// A broadcast stream of incoming [TelemetryPoint] objects.
  ///
  /// Subscribe to this stream to receive real-time coordinate updates
  /// as they arrive from peer atSigns. Each emitted point has already
  /// been decrypted, parsed, and persisted to SQLite.
  Stream<TelemetryPoint> get pointStream => _pointController.stream;

  // ── Listening Control ──────────────────────────────────────────────────────

  /// Starts listening for inbound location telemetry notifications.
  ///
  /// Opens the monitor connection (if not already open) and subscribes
  /// to notifications matching the `.AtNav` namespace regex pattern.
  void startListening() {
    if (_isListening) return;
    if (!_atService.isAuthenticated) {
      _lastError = 'Cannot listen: not authenticated';
      notifyListeners();
      return;
    }

    try {
      // Subscribe to notifications filtered by the app namespace.
      // The regex `\.AtNav` ensures we only receive location notifications
      // from this application, not other Atsign apps.
      _notificationSubscription = _atService.notificationService
          .subscribe(
            regex: _atService.locationNotificationRegex,
            shouldDecrypt: true,
          )
          .listen(
            _onNotificationReceived,
            onError: _onNotificationError,
            onDone: _onNotificationDone,
            cancelOnError: false,
          );

      _isListening = true;
      _lastError = null;
      notifyListeners();

      debugPrint(
        '[TelemetryListener] Started listening on namespace '
        '${AppConstants.appNamespace}',
      );
    } catch (e) {
      _lastError = 'Failed to start listening: $e';
      _isListening = false;
      notifyListeners();
      debugPrint('[TelemetryListener] Start error: $e');
    }
  }

  /// Stops listening for inbound notifications.
  void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _isListening = false;
    notifyListeners();
    debugPrint('[TelemetryListener] Stopped listening');
  }

  // ── Notification Handlers ──────────────────────────────────────────────────

  /// Processes a single inbound notification.
  ///
  /// The SDK has already:
  /// 1. Received the notification via the monitor socket
  /// 2. Extracted `sharedKeyEnc` and `ivNonce` from metadata
  /// 3. RSA-decrypted the shared symmetric key
  /// 4. AES-256-decrypted the value using the shared key + IV
  ///
  /// We receive the plaintext JSON value ready for parsing.
  void _onNotificationReceived(AtNotification notification) {
    try {
      // Only process update notifications with values
      if (notification.value == null || notification.value!.isEmpty) {
        return;
      }

      // Only process location key notifications
      if (!notification.key.contains(AppConstants.locationKeyName)) {
        return;
      }

      // Extract the sender's atSign from the notification
      final senderAtSign = notification.from;

      // Parse the decrypted JSON payload into a TelemetryPoint
      final point = TelemetryPoint.fromNotificationJson(
        notification.value!,
        senderAtSign,
      );

      // Persist to local SQLite database
      _localDb.insertCoordinate(point);

      // Update state
      _receivedCount++;
      _lastReceivedPoint = point;
      _lastError = null;

      // Emit on the broadcast stream for real-time UI updates
      _pointController.add(point);

      notifyListeners();

      debugPrint(
        '[TelemetryListener] Received from $senderAtSign: '
        '${point.latitude.toStringAsFixed(4)}, '
        '${point.longitude.toStringAsFixed(4)}',
      );
    } catch (e) {
      _lastError = 'Parse error: $e';
      notifyListeners();
      debugPrint('[TelemetryListener] Parse error: $e');
    }
  }

  /// Handles errors on the notification stream.
  void _onNotificationError(Object error) {
    _lastError = 'Notification stream error: $error';
    notifyListeners();
    debugPrint('[TelemetryListener] Stream error: $error');
  }

  /// Called when the notification stream completes (connection lost).
  void _onNotificationDone() {
    debugPrint(
      '[TelemetryListener] Notification stream completed. '
      'Attempting reconnection...',
    );

    // The SDK auto-reconnects the monitor connection, but we need to
    // re-subscribe if the stream completes unexpectedly.
    _isListening = false;
    notifyListeners();

    // Schedule a reconnection attempt after a brief delay
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isListening && _atService.isAuthenticated) {
        debugPrint('[TelemetryListener] Reconnecting...');
        startListening();
      }
    });
  }

  @override
  void dispose() {
    stopListening();
    _pointController.close();
    super.dispose();
  }
}
