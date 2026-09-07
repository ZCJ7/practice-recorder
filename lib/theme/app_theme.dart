import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const ink = Color(0xFF1A1C1E);
  static const muted = Color(0xFF5C6570);
  static const line = Color(0xFFD8DEE6);
  static const paper = Color(0xFFF3F5F8);
  static const paperDeep = Color(0xFFE7EBF1);
  static const accent = Color(0xFFC45C26);
  static const record = Color(0xFFD62828);
  static const best = Color(0xFFB8860B);
  static const keep = Color(0xFF2F6B4F);
  static const danger = Color(0xFFB42318);
  static const white = Color(0xFFFFFFFF);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      primary: AppColors.accent,
      surface: AppColors.paper,
    ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.notoSansScTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.libreFranklin(
        fontWeight: FontWeight.w700,
        fontSize: 36,
        color: AppColors.ink,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.libreFranklin(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        color: AppColors.ink,
      ),
      titleLarge: GoogleFonts.libreFranklin(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: AppColors.ink,
      ),
      titleMedium: GoogleFonts.notoSansSc(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AppColors.ink,
      ),
      bodyLarge: GoogleFonts.notoSansSc(
        fontSize: 16,
        color: AppColors.ink,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.notoSansSc(
        fontSize: 14,
        color: AppColors.muted,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.notoSansSc(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: AppColors.ink,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.libreFranklin(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: AppColors.ink,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 32,
    ),
  );
}

String formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

String formatDurationHuman(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  if (h > 0) {
    return '$h小时$m分钟';
  }
  if (m > 0) {
    return '$m分钟';
  }
  return '$totalSeconds秒';
}
