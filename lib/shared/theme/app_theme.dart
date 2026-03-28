import 'package:flutter/material.dart';

/// OS-aware light and dark themes for Yap.
///
/// The overlay uses a semi-transparent background so it floats above
/// whatever app the user is working in.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Colours
  // ---------------------------------------------------------------------------

  static const Color _primaryLight = Color(0xFF6C63FF);
  static const Color _primaryDark = Color(0xFF9D97FF);

  /// Semi-transparent overlay background (light mode).
  static const Color overlayBackgroundLight = Color(0xE6FFFFFF); // ~90 %

  /// Semi-transparent overlay background (dark mode).
  static const Color overlayBackgroundDark = Color(0xE61E1E1E);

  // ---------------------------------------------------------------------------
  // Text styles (for transcript display)
  // ---------------------------------------------------------------------------

  static const TextStyle transcriptStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle transcriptStyleBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  static final ThemeData light = ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: _primaryLight,
    useMaterial3: true,
    scaffoldBackgroundColor: overlayBackgroundLight,
    fontFamily: 'system-ui',
  );

  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: _primaryDark,
    useMaterial3: true,
    scaffoldBackgroundColor: overlayBackgroundDark,
    fontFamily: 'system-ui',
  );
}
