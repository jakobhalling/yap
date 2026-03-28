import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OS-aware theme using Inter font family.
class AppTheme {
  AppTheme._();

  static final _textTheme = GoogleFonts.interTextTheme();

  static final light = ThemeData(
    brightness: Brightness.light,
    textTheme: _textTheme,
    colorSchemeSeed: Colors.blue,
    useMaterial3: true,
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    colorSchemeSeed: Colors.blue,
    useMaterial3: true,
  );

  // Keep these for any non-overlay usage
  static const overlayBackgroundDark = Color(0xE0141414);
  static const overlayBackgroundLight = Color(0xE0FAFAFA);

  static final transcriptStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
}
