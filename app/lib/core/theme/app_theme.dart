import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.coral,
        secondary: AppColors.sage,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
      ),
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.ink,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// Shared text styles used across screens.
class T {
  T._();
  static TextStyle h1(BuildContext c) => GoogleFonts.plusJakartaSans(
      fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.1);
  static TextStyle h2(BuildContext c) => GoogleFonts.plusJakartaSans(
      fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink);
  static TextStyle title(BuildContext c) => GoogleFonts.plusJakartaSans(
      fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink);
  static TextStyle body(BuildContext c) => GoogleFonts.plusJakartaSans(
      fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.inkMid, height: 1.4);
  static TextStyle label(BuildContext c) => GoogleFonts.plusJakartaSans(
      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: 0.8);
  static TextStyle small(BuildContext c) => GoogleFonts.plusJakartaSans(
      fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkSoft);
}
