import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _brand = Color(0xFF0F766E);
const Color _brandDark = Color(0xFF134E4A);
const Color _surfaceTint = Color(0xFFF7F8FA);
const Color _ink = Color(0xFF101828);

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.light,
      primary: _brand,
      secondary: const Color(0xFF14B8A6),
      surface: Colors.white,
      onSurface: _ink,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: _surfaceTint,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: _ink,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: _brand.withValues(alpha: 0.12),
      labelTextStyle: MaterialStateProperty.all(
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
      primary: const Color(0xFF5EEAD4),
      secondary: const Color(0xFF2DD4BF),
      surface: const Color(0xFF0B1120),
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF08111E),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF101A2B),
      surfaceTintColor: const Color(0xFF101A2B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
