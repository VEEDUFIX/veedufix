import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _brand = Color(0xFFC2A15E);
const Color _brandDark = Color(0xFFB38D46);
const Color _brandContainer = Color(0xFFF5E8CC);
const Color _surfaceTint = Color(0xFFF9F5EC);
const Color _ink = Color(0xFF111827);
const Color _outline = Color(0xFFE5E7EB);
const Color _success = Color(0xFF10B981);
const Color _warning = Color(0xFFF59E0B);
const Color _error = Color(0xFFEF4444);

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.light,
      primary: _brand,
      primaryContainer: _brandContainer,
      secondary: _success,
      secondaryContainer: const Color(0xFFD1FAE5),
      tertiary: _warning,
      tertiaryContainer: const Color(0xFFFFE7BA),
      error: _error,
      errorContainer: const Color(0xFFFEE2E2),
      surface: Colors.white,
      onSurface: _ink,
      outline: _outline,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: _surfaceTint,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: _ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _brand, width: 1.2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      indicatorColor: _brand.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brandDark,
      brightness: Brightness.dark,
      primary: const Color(0xFFF1D8AA),
      primaryContainer: const Color(0xFF5C4621),
      secondary: const Color(0xFF6EE7B7),
      tertiary: const Color(0xFFFCD34D),
      error: const Color(0xFFFCA5A5),
      surface: const Color(0xFF0B1220),
      onSurface: Colors.white,
      outline: const Color(0xFF243247),
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF07111E),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    splashFactory: InkSparkle.splashFactory,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111B2D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF243247)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFF1D8AA), width: 1.2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF0F172A),
      surfaceTintColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
