import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'meetday_colors.dart';

export 'meetday_colors.dart';
export 'meetday_card.dart';
export 'meetday_button.dart';
export 'meetday_badge.dart';

class AppTheme {
  static const Color primary = MeetdayColors.primaryRed;
  static const Color accent = MeetdayColors.accentYellow;
  static const Color background = MeetdayColors.background;
  static const Color surface = MeetdayColors.cardWhite;
  static const Color textPrimary = MeetdayColors.textPrimary;
  static const Color textSecondary = MeetdayColors.textSecondary;
  static const Color border = MeetdayColors.inkBlack;
  static const Color warning = MeetdayColors.accentYellow;
  static const Color error = MeetdayColors.primaryRed;
  static const Color info = MeetdayColors.hubBlue;

  static ThemeData lightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: MeetdayColors.primaryRed,
        onPrimary: Colors.white,
        secondary: MeetdayColors.accentYellow,
        onSecondary: MeetdayColors.inkBlack,
        error: MeetdayColors.primaryRed,
        onError: Colors.white,
        surface: MeetdayColors.cardWhite,
        onSurface: MeetdayColors.textPrimary,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        headlineLarge: GoogleFonts.bricolageGrotesque(
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.bricolageGrotesque(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.bricolageGrotesque(
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.bricolageGrotesque(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.bricolageGrotesque(
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.bricolageGrotesque(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: border, width: 2),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    return base;
  }
}
