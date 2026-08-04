import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ui/widgets/abzio_motion.dart';

class AbzioTheme {
  static const Color accentColor = Color(0xFFC2A15E);
  static const Color primaryColor = lightBackground;
  static const Color backgroundColor = lightBackground;
  static const Color cardColor = lightCard;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color grey50 = Color(0xFFFFFFFF);
  static const Color grey100 = Color(0xFFF7F1E4);
  static const Color grey200 = Color(0xFFF1E6D4);
  static const Color grey300 = lightBorder;
  static const Color grey400 = Color(0xFFD2D2D2);
  static const Color grey500 = Color(0xFF8B8B8B);
  static const Color grey600 = lightTextSecondary;

  static const Color lightBackground = Color(0xFFF9F5EC);
  static const Color lightCard = Color(0xFFFFFDF9);
  static const Color lightTextPrimary = Color(0xFF13110F);
  static const Color lightTextSecondary = Color(0xFF6B6256);
  static const Color lightBorder = Color(0xFFE5D8C6);
  static const Color lightMuted = Color(0xFFF7F1E4);

  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing40 = 40;
  static const double cardRadius = 28;
  static const double buttonRadius = 18;
  static const double inputRadius = 20;
  static const double sectionGap = 32;
  static const double cardPadding = 24;
  static const double screenHorizontalPadding = 24;
  static const double minimumTouchTarget = 48;
  static const double fieldHeight = 64;
  static const double internalSpacing = spacing16;

  static List<BoxShadow> shadowFor(Brightness brightness) => [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.14 : 0.06,
          ),
          blurRadius: brightness == Brightness.dark ? 16 : 10,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get eliteShadow => shadowFor(Brightness.light);

  static final PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const AbzioPageTransitionsBuilder(),
    },
  );

  static ThemeData get lightTheme => _buildTheme(brightness: Brightness.light);

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF16120D) : lightBackground;
    final canvas = isDark ? const Color(0xFF1C1711) : const Color(0xFFFFFBF5);
    final card = isDark ? const Color(0xFF211B14) : lightCard;
    final elevated = isDark ? const Color(0xFF261F17) : const Color(0xFFFFFCF8);
    final textPrimary = isDark ? const Color(0xFFF6EEE2) : lightTextPrimary;
    final textSecondary = isDark ? const Color(0xFFCDBEA9) : lightTextSecondary;
    final border = isDark ? const Color(0xFF3A3125) : lightBorder;
    final muted = isDark ? const Color(0xFF2B241A) : lightMuted;

    final colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: accentColor,
      primary: accentColor,
      secondary: accentColor,
      surface: card,
      error: const Color(0xFFD16A57),
    ).copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: textPrimary,
      onError: Colors.white,
    );

    final textTheme = TextTheme(
      displayLarge: GoogleFonts.cormorantGaramond(
        color: textPrimary,
        fontSize: 42,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.9,
        height: 0.95,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1.0,
      ),
      headlineLarge: GoogleFonts.cormorantGaramond(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.02,
      ),
      headlineMedium: GoogleFonts.cormorantGaramond(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.05,
      ),
      titleLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        height: 1.15,
      ),
      titleMedium: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleSmall: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      bodyLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.55,
      ),
      bodyMedium: GoogleFonts.outfit(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.outfit(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      labelLarge: GoogleFonts.outfit(
        color: accentColor,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.outfit(
        color: accentColor,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
      labelSmall: GoogleFonts.outfit(
        color: textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.45,
      ),
    );

    final baseRadius = BorderRadius.circular(cardRadius);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: accentColor,
      scaffoldBackgroundColor: background,
      canvasColor: canvas,
      cardColor: card,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: GoogleFonts.outfit().fontFamily,
      pageTransitionsTheme: _pageTransitions,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary, size: 22),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      splashColor: accentColor.withValues(alpha: 0.08),
      highlightColor: accentColor.withValues(alpha: 0.04),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: isDark ? 0.7 : 0.9),
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: elevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: elevated,
        modalBarrierColor: Colors.black.withValues(alpha: 0.45),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: muted,
        selectedColor: accentColor.withValues(alpha: 0.15),
        side: BorderSide(color: border),
        shape: StadiumBorder(side: BorderSide(color: border)),
        labelStyle: textTheme.labelMedium?.copyWith(color: textPrimary),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
          elevation: 0,
          animationDuration: AbzioMotion.medium,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            accentColor.withValues(alpha: 0.10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border, width: 1.1),
          animationDuration: AbzioMotion.medium,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            accentColor.withValues(alpha: 0.08),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          animationDuration: AbzioMotion.medium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            accentColor.withValues(alpha: 0.08),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2218) : const Color(0xFFFDF8F0),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: accentColor, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFD24B4B), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFD24B4B), width: 1.3),
        ),
        floatingLabelStyle: GoogleFonts.outfit(
          color: accentColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: GoogleFonts.outfit(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: GoogleFonts.outfit(color: textSecondary, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF221B14) : const Color(0xFF15110D),
        contentTextStyle: GoogleFonts.outfit(
          color: isDark ? const Color(0xFFF5EEDF) : const Color(0xFFFFF8F0),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: elevated,
        indicatorColor: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? accentColor : textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            color: selected ? textPrimary : textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: accentColor.withValues(alpha: 0.28),
        selectionHandleColor: accentColor,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    );
  }
}

extension AbzioThemeContext on BuildContext {
  ColorScheme get abzioColors => Theme.of(this).colorScheme;
  TextTheme get abzioText => Theme.of(this).textTheme;
  Color get abzioBorder => AbzioTheme.lightBorder;
  Color get abzioMuted => AbzioTheme.lightMuted;
  Color get abzioSecondaryText => AbzioTheme.lightTextSecondary;
  List<BoxShadow> get abzioShadow =>
      AbzioTheme.shadowFor(Theme.of(this).brightness);
}
