import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants.dart';
import 'features/ui/map_screen.dart';
import 'features/ui/onboarding_screen.dart';
import 'features/ui/theme.dart';

/// AtNav — Decentralized E2E Encrypted Desktop Location Sharing
///
/// Root entrypoint bootstrapping the application context:
/// - Configures desktop window (title, size, minimum constraints)
/// - Sets global error/exception handlers
/// - Routes between OnboardingScreen and MapScreen based on auth state
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // ── Desktop Window Configuration ───────────────────────────────────────────
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
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
