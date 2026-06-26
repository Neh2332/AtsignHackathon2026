import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean Orange and White design system for AtNav.
///
/// Visual archetype: **Modern App**
/// Derived from Atsign's branding colors.
///
/// Rules enforced:
/// - Light substrate exclusively (`#FFFFFF`)
/// - Rounded corners for friendliness
/// - Clean sans-serif typography (Inter)
/// - Primary accent: Atsign Orange (`#FF5A00`)
/// - Soft borders and dividers
class AtNavTheme {
  AtNavTheme._();

  // ── Color Palette ──────────────────────────────────────────────────────────
  /// Pure white background.
  static const Color bgPrimary = Color(0xFFFFFFFF);

  /// Slightly elevated surface for cards and panels.
  static const Color bgSurface = Color(0xFFF9F9F9);

  /// Elevated compartment background.
  static const Color bgElevated = Color(0xFFF0F0F0);

  /// Dark text — primary foreground.
  static const Color fgPrimary = Color(0xFF1A1A1A);

  /// Dimmed secondary text for metadata and labels.
  static const Color fgSecondary = Color(0xFF666666);

  /// Muted tertiary text for timestamps and supplementary info.
  static const Color fgTertiary = Color(0xFF999999);

  /// Atsign Orange — the ONLY accent color.
  /// Used for: active pins, alerts, section dividers, critical indicators.
  static const Color accentOrange = Color(0xFFFD582C);

  /// Terminal Green — used for ONE element only: live connection status.
  static const Color terminalGreen = Color(0xFF34C759);

  /// Grid line color for structural dividers.
  static const Color gridLine = Color(0x1A000000); 

  /// Border color for compartment edges.
  static const Color borderColor = Color(0xFFE0E0E0);

  /// Thick structural divider color.
  static const Color dividerStrong = Color(0xFFFF5A00);

  // ── Typography ─────────────────────────────────────────────────────────────

  /// Macro typography: Sans-serif for structural headers.
  static TextStyle macroHeader(double size) {
    return GoogleFonts.inter(
      fontSize: size,
      color: fgPrimary,
      letterSpacing: -0.02 * size,
      height: 1.1,
      fontWeight: FontWeight.w700,
    );
  }

  /// Micro typography: Inter for all data, coordinates, timestamps.
  static TextStyle monoData({
    double size = 12,
    Color color = fgPrimary,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      color: color,
      height: 1.3,
      fontWeight: weight,
    );
  }

  /// Label typography: Smaller, for section labels and metadata.
  static TextStyle monoLabel({
    double size = 10,
    Color color = fgSecondary,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      color: color,
      letterSpacing: size * 0.05,
      height: 1.2,
      fontWeight: FontWeight.w600,
    );
  }

  /// Section header framing.
  static String asciiFrame(String text) => text.toUpperCase();

  /// Directional indicator.
  static String asciiArrow(String text) => '→ ${text.toUpperCase()}';

  // ── Borders & Decoration ───────────────────────────────────────────────────

  /// Standard compartment border (1px solid).
  static const Border compartmentBorder = Border.fromBorderSide(
    BorderSide(color: borderColor, width: 1),
  );

  /// Strong horizontal divider.
  static const Border strongDivider = Border(
    bottom: BorderSide(color: accentOrange, width: 2),
  );

  /// Panel decoration with compartment border and light background.
  static BoxDecoration panelDecoration({Color? backgroundColor}) {
    return BoxDecoration(
      color: backgroundColor ?? bgSurface,
      border: Border.all(color: borderColor, width: 1),
      borderRadius: BorderRadius.circular(8),
    );
  }

  // ── Component Styles ───────────────────────────────────────────────────────

  /// Input field decoration.
  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label.toUpperCase(),
      labelStyle: monoLabel(size: 10, color: fgSecondary),
      hintText: hint,
      hintStyle: monoData(size: 12, color: fgTertiary),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: bgPrimary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: accentOrange, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: accentOrange, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: accentOrange, width: 2),
      ),
    );
  }

  /// Modern button style.
  static ButtonStyle primaryButton({bool isDestructive = false}) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return bgElevated;
        }
        if (states.contains(WidgetState.pressed)) {
          return isDestructive ? const Color(0xFFE04900) : const Color(0xFFF0F0F0);
        }
        return isDestructive ? accentOrange : bgSurface;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (isDestructive && !states.contains(WidgetState.disabled)) {
          return Colors.white;
        }
        return fgPrimary;
      }),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return const BorderSide(color: accentOrange, width: 1);
        }
        return BorderSide(
          color: isDestructive ? accentOrange : borderColor,
          width: 1,
        );
      }),
      textStyle: WidgetStateProperty.all(
        monoData(size: 12, weight: FontWeight.w600),
      ),
      overlayColor: WidgetStateProperty.all(accentOrange.withValues(alpha: 0.1)),
    );
  }

  // ── Full Theme Data ────────────────────────────────────────────────────────

  /// Builds the complete [ThemeData] for the AtNav application.
  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: const ColorScheme.light(
        primary: accentOrange,
        secondary: fgSecondary,
        surface: bgSurface,
        error: accentOrange,
        onPrimary: Colors.white,
        onSecondary: fgPrimary,
        onSurface: fgPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgPrimary,
        foregroundColor: fgPrimary,
        elevation: 0,
        titleTextStyle: macroHeader(18),
        toolbarHeight: 48,
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 0,
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      iconTheme: const IconThemeData(
        color: fgSecondary,
        size: 16,
      ),
      textTheme: TextTheme(
        headlineLarge: macroHeader(32),
        headlineMedium: macroHeader(24),
        headlineSmall: macroHeader(18),
        bodyLarge: monoData(size: 14),
        bodyMedium: monoData(size: 12),
        bodySmall: monoData(size: 10, color: fgSecondary),
        labelLarge: monoLabel(size: 11),
        labelMedium: monoLabel(size: 10),
        labelSmall: monoLabel(size: 9),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(fgTertiary),
        thickness: WidgetStateProperty.all(4),
        radius: const Radius.circular(4),
      ),
    );
  }

  // ── CRT Effects (Removed) ──────────────────────────────────────────────────
  static Widget scanlineOverlay() {
    return const SizedBox.shrink();
  }
}
