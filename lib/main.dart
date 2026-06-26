import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/ui/map_screen.dart';
import 'features/ui/onboarding_screen.dart';
import 'features/ui/theme.dart';

/// AtNav — Decentralized E2E Encrypted Location Sharing
///
/// Root entrypoint bootstrapping the application context:
/// - Sets global error/exception handlers
/// - Locks orientation to portrait on mobile
/// - Routes between OnboardingScreen and MapScreen based on auth state
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Lock to portrait on mobile ─────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
