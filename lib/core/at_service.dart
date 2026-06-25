import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_auth/at_auth.dart';
import 'package:at_utils/at_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

import 'constants.dart';

/// Singleton wrapper around the Atsign Protocol [AtClientManager].
///
/// Handles:
/// - Desktop-specific storage path configuration
/// - `.atKeys` file loading and PKAM authentication
/// - Exposing [AtClient], [NotificationService], and [SyncService]
/// - Connection lifecycle management with exponential backoff reconnection
///
/// This class is the single point of contact between the application
/// and the Atsign Protocol infrastructure. All feature-layer services
/// obtain their protocol handles through this wrapper.
class AtService extends ChangeNotifier {
  AtService._();
  static final AtService _instance = AtService._();
  static AtService get instance => _instance;

  AtClientManager? _atClientManager;
  String? _currentAtSign;
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;
  String? _authError;

  // ── Public Getters ─────────────────────────────────────────────────────────

  /// The active [AtClient] instance. Throws if not authenticated.
  AtClient get atClient {
    if (_atClientManager == null) {
      throw StateError('AtService not initialized. Call authenticate() first.');
    }
    return _atClientManager!.atClient;
  }

  /// The notification service for pub/sub messaging.
  NotificationService get notificationService => atClient.notificationService;

  /// The sync service for background synchronization.
  SyncService get syncService => atClient.syncService;

  /// The currently authenticated atSign (e.g., `@alice`).
  String? get currentAtSign => _currentAtSign;

  /// Whether the service is authenticated and ready.
  bool get isAuthenticated => _isAuthenticated;

  /// Whether authentication is in progress.
  bool get isAuthenticating => _isAuthenticating;

  /// The last authentication error message, if any.
  String? get authError => _authError;

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Authenticates with the Atsign Protocol using a `.atKeys` file.
  ///
  /// [atSign] — The atSign to authenticate (e.g., `@alice`)
  /// [atKeysFilePath] — Absolute path to the `.atKeys` backup file
  ///
  /// This method:
  /// 1. Reads the `.atKeys` file from disk
  /// 2. Configures desktop-specific storage directories
  /// 3. Initializes the [AtClientManager] with [AtClientPreference]
  /// 4. Performs PKAM authentication using the keys from the file
  /// 5. Starts the background sync service
  Future<bool> authenticate({
    required String atSign,
    required String atKeysFilePath,
  }) async {
    if (_isAuthenticating) return false;

    _isAuthenticating = true;
    _authError = null;
    notifyListeners();

    try {
      // Normalize the atSign (ensure @ prefix)
      final normalizedAtSign = AtUtils.fixAtSign(atSign);

      // Configure desktop storage paths
      final appDocDir = await getApplicationSupportDirectory();
      final atSignStoragePath = p.join(
        appDocDir.path,
        'AtNav',
        normalizedAtSign.replaceAll('@', ''),
      );

      // Ensure storage directory exists
      final storageDir = Directory(atSignStoragePath);
      if (!storageDir.existsSync()) {
        storageDir.createSync(recursive: true);
      }

      // Build AtClientPreference for desktop
      final atClientPreference = AtClientPreference()
        ..rootDomain = AppConstants.rootDomain
        ..rootPort = AppConstants.rootPort
        ..namespace = AppConstants.appNamespace
        ..hiveStoragePath = p.join(atSignStoragePath, 'hive')
        ..commitLogPath = p.join(atSignStoragePath, 'commitLog')
        ..syncIntervalMins = 1
        ..fetchOfflineNotifications = true;

      // Perform PKAM authentication using at_auth
      final atAuth = AtAuth.create();
      final authResult = await atAuth.authenticate(
        AtAuthRequest(
          normalizedAtSign,
          atKeysIo: FileAtKeysIo(filePath: (atSign) => atKeysFilePath),
        ),
      );

      if (authResult.isSuccessful) {
        // Initialize AtClientManager
        _atClientManager = await AtClientManager.getInstance().setCurrentAtSign(
          normalizedAtSign,
          AppConstants.appNamespace,
          atClientPreference,
          atChops: authResult.atChops,
          atLookUp: authResult.atLookUp,
          enrollmentId: authResult.enrollmentId,
        );

        _currentAtSign = normalizedAtSign;
        _isAuthenticated = true;
        _authError = null;

        debugPrint(
          '[AtService] Successfully authenticated as $normalizedAtSign',
        );

        // Start sync service
        syncService.sync();
      } else {
        _authError = 'Authentication failed';
        _isAuthenticated = false;
        debugPrint('[AtService] Authentication failed: $_authError');
      }
    } catch (e, stack) {
      _authError = 'Authentication error: ${e.toString()}';
      _isAuthenticated = false;
      debugPrint('[AtService] Error during authentication: $e');
      debugPrint('[AtService] Stack trace: $stack');
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }

    return _isAuthenticated;
  }

  /// Signs out and resets the service state.
  Future<void> signOut() async {
    _currentAtSign = null;
    _isAuthenticated = false;
    _atClientManager = null;
    _authError = null;
    notifyListeners();
  }

  // ── Utility Methods ────────────────────────────────────────────────────────

  /// Constructs an [AtKey] for location telemetry addressed to [recipientAtSign].
  ///
  /// Wire shape: `@recipient:location.AtNav@self`
  /// Metadata: `ttln = 60000` (60-second ephemeral notification)
  AtKey buildLocationKey(String recipientAtSign) {
    final key = AtKey()
      ..key = AppConstants.locationKeyName
      ..namespace = AppConstants.appNamespace
      ..sharedWith = AtUtils.fixAtSign(recipientAtSign)
      ..sharedBy = _currentAtSign
      ..metadata = (Metadata()..ttl = AppConstants.notificationTtlnMs);
    return key;
  }

  /// Returns the notification regex pattern for filtering location updates
  /// in the monitor stream.
  ///
  /// Filters to: `*.AtNav` namespace only.
  String get locationNotificationRegex => '.${AppConstants.appNamespace}';
}
