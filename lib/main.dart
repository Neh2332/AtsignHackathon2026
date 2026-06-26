import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';

import 'core/constants.dart';
import 'features/ui/map_screen.dart';
import 'features/ui/onboarding_screen.dart';
import 'features/ui/theme.dart';

/// AtNav — Decentralized E2E Encrypted Location Sharing
///
/// Root entrypoint bootstrapping the application context:
/// - Sets global error/exception handlers
/// - On desktop: configures window size, minimum constraints, and title
/// - On mobile: locks orientation to portrait
/// - Routes between OnboardingScreen and MapScreen based on auth state
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isDesktop = false;
  bool isMobile = false;

  if (!kIsWeb) {
    isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    isMobile = Platform.isAndroid || Platform.isIOS;
  }

  // ── Mobile: Lock orientation to portrait ───────────────────────────────────
  if (isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // ── Desktop: Configure window size and position ────────────────────────────
  if (isDesktop) {
    await windowManager.ensureInitialized();

    const WindowOptions windowOptions = WindowOptions(
      size: Size(
        AppConstants.initialWindowWidth,
        AppConstants.initialWindowHeight,
      ),
      minimumSize: Size(
        AppConstants.minWindowWidth,
        AppConstants.minWindowHeight,
      ),
      center: true,
      backgroundColor: AtNavTheme.bgPrimary,
      title: 'AtNav /// Decentralized Location Sharing',
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // ── Global Error Handling ──────────────────────────────────────────────────
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[AtNav] Flutter error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[AtNav] Platform error: $error');
    debugPrint('[AtNav] Stack: $stack');
    return true;
  };

  runApp(const AtNavApp());
}

/// Root application widget.
///
/// Manages the authentication state and routes between:
/// - [OnboardingScreen] — .atKeys file authentication
/// - [MapScreen] — Main map dashboard (post-authentication)
class AtNavApp extends StatefulWidget {
  const AtNavApp({super.key});

  @override
  State<AtNavApp> createState() => _AtNavAppState();
}

class _AtNavAppState extends State<AtNavApp> {
  bool _isAuthenticated = false;

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AtNav',
      debugShowCheckedModeBanner: false,
      theme: AtNavTheme.buildTheme(),
      home: _isAuthenticated
          ? const MapScreen()
          : OnboardingScreen(onAuthenticated: _onAuthenticated),
    );
  }
}
