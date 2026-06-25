import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/at_service.dart';
import '../../core/constants.dart';
import '../../models/telemetry_point.dart';

/// The publishing pipeline for location telemetry.
///
/// Responsible for:
/// 1. Polling the device's location provider at configurable intervals
/// 2. Packaging coordinates as compact JSON payloads
/// 3. Encrypting and transmitting via the Atsign NotificationService
///    with strict `ttln` constraints (60-second ephemeral TTL)
///
/// Design rationale:
/// - Notifications with `ttln` bypass the server-side commit log entirely,
///   preventing high-frequency coordinate data from bloating the atServer.
/// - Each notification is E2E encrypted by the SDK transparently using the
///   counterparty's shared symmetric key (AES-256).
/// - Multi-peer fan-out: coordinates are sent to each subscribed peer
///   independently.
class TelemetryStreamer extends ChangeNotifier {
  final AtService _atService;

  Timer? _streamTimer;
  StreamSubscription<Position>? _positionSubscription;
  bool _isStreaming = false;
  Position? _lastPosition;
  DateTime? _lastBroadcastTime;
  String? _lastError;

  /// The set of peer atSigns currently receiving location updates.
  final Set<String> _recipients = {};

  TelemetryStreamer(this._atService);

  // ── Public Getters ─────────────────────────────────────────────────────────

  bool get isStreaming => _isStreaming;
  Position? get lastPosition => _lastPosition;
  DateTime? get lastBroadcastTime => _lastBroadcastTime;
  String? get lastError => _lastError;
  Set<String> get recipients => Set.unmodifiable(_recipients);

  // ── Recipient Management ───────────────────────────────────────────────────

  /// Adds a peer atSign to the broadcast list.
  void addRecipient(String atSign) {
    final normalized = _normalizeAtSign(atSign);
    _recipients.add(normalized);
    notifyListeners();
  }

  /// Removes a peer atSign from the broadcast list.
  void removeRecipient(String atSign) {
    final normalized = _normalizeAtSign(atSign);
    _recipients.remove(normalized);
    notifyListeners();
  }

  /// Clears all recipients.
  void clearRecipients() {
    _recipients.clear();
    notifyListeners();
  }

  // ── Streaming Control ──────────────────────────────────────────────────────

  /// Starts broadcasting location telemetry to all current recipients.
  ///
  /// Checks location permissions, begins polling the platform location
  /// provider, and sends encrypted notifications at the configured interval.
  Future<void> startStreaming() async {
    if (_isStreaming) return;
    if (!_atService.isAuthenticated) {
      _lastError = 'Cannot stream: not authenticated';
      notifyListeners();
      return;
    }

    try {
      // Check and request location permissions
      final permission = await _checkLocationPermission();
      if (!permission) {
        _lastError = 'Location permission denied';
        notifyListeners();
        return;
      }

      _isStreaming = true;
      _lastError = null;
      notifyListeners();

      // Start periodic broadcasting
      _streamTimer = Timer.periodic(
        const Duration(seconds: AppConstants.telemetryIntervalSeconds),
        (_) => _broadcastCurrentPosition(),
      );

      // Send immediately on start
      await _broadcastCurrentPosition();
    } catch (e) {
      _lastError = 'Failed to start streaming: $e';
      _isStreaming = false;
      notifyListeners();
    }
  }

  /// Stops broadcasting location telemetry.
  void stopStreaming() {
    _streamTimer?.cancel();
    _streamTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isStreaming = false;
    notifyListeners();
  }

  // ── Internal Methods ───────────────────────────────────────────────────────

  /// Fetches the current position and broadcasts it to all recipients.
  Future<void> _broadcastCurrentPosition() async {
    if (!_isStreaming || _recipients.isEmpty) return;

    try {
      // Get current position from the platform
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      _lastPosition = position;

      // Build the telemetry point
      final point = TelemetryPoint(
        peerAtSign: _atService.currentAtSign!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now().toUtc(),
        receivedAt: DateTime.now().toUtc(),
      );

      // Fan-out to all recipients
      final futures = _recipients.map(
        (recipient) => _sendToRecipient(point, recipient),
      );
      await Future.wait(futures, eagerError: false);

      _lastBroadcastTime = DateTime.now().toUtc();
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Broadcast error: $e';
      debugPrint('[TelemetryStreamer] Broadcast error: $e');
      notifyListeners();
    }
  }

  /// Sends an encrypted telemetry notification to a single recipient.
  ///
  /// The notification is constructed with:
  /// - Key: `@recipient:location.AtNav@self`
  /// - Value: JSON `{lat, lng, ts, acc}` (encrypted by SDK)
  /// - TTL-N: 60 seconds (ephemeral — bypasses server commit log)
  Future<void> _sendToRecipient(
    TelemetryPoint point,
    String recipientAtSign,
  ) async {
    try {
      final atKey = _atService.buildLocationKey(recipientAtSign);
      final jsonPayload = point.toTransmissionJson();

      // The SDK handles:
      // 1. Generating a random IV nonce
      // 2. AES-256 encrypting the value with the shared symmetric key
      // 3. RSA-encrypting the shared key to the recipient's public key
      // 4. Setting sharedKeyEnc and ivNonce in the metadata
      // 5. Transmitting via the notify verb with ttln constraint
      final notificationResult = await _atService
          .notificationService
          .notify(
            NotificationParams.forUpdate(
              atKey,
              value: jsonPayload,
            ),
          );

      debugPrint(
        '[TelemetryStreamer] Sent to $recipientAtSign: '
        '${point.latitude.toStringAsFixed(4)}, '
        '${point.longitude.toStringAsFixed(4)} '
        '(notification: ${notificationResult.notificationID})',
      );
    } catch (e) {
      debugPrint(
        '[TelemetryStreamer] Failed to send to $recipientAtSign: $e',
      );
    }
  }

  /// Checks and requests location permission from the platform.
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[TelemetryStreamer] Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[TelemetryStreamer] Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        '[TelemetryStreamer] Location permission permanently denied',
      );
      return false;
    }

    return true;
  }

  /// Normalizes an atSign string (ensures `@` prefix).
  String _normalizeAtSign(String atSign) {
    if (!atSign.startsWith('@')) {
      return '@$atSign';
    }
    return atSign;
  }

  @override
  void dispose() {
    stopStreaming();
    super.dispose();
  }
}
