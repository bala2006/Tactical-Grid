import 'package:flutter/material.dart';

class GameColors {
  static const background = Color(0xFF0B1222);
  static const backgroundSoft = Color(0xFF10192E);
  static const panel = Color(0xFF18253F);
  static const panelSoft = Color(0xFF213150);
  static const panelStrong = Color(0xFF27406A);
  static const border = Color(0x297A9CD2);
  static const borderStrong = Color(0x577A9CD2);
  static const text = Color(0xFFF3F6FB);
  static const muted = Color(0xFF8FB1E0);
  static const accent = Color(0xFF6FB4FF);
  static const accentSoft = Color(0x296FB4FF);
  static const danger = Color(0xFFF28482);
}

ThemeData buildGameTheme() {
  const textTheme = TextTheme(
    headlineMedium: TextStyle(
      color: GameColors.text,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      height: 1.0,
    ),
    titleMedium: TextStyle(
      color: GameColors.text,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    ),
    bodyMedium: TextStyle(color: GameColors.text, fontSize: 12, height: 1.3),
    bodySmall: TextStyle(color: GameColors.muted, fontSize: 10.5, height: 1.35),
    labelMedium: TextStyle(
      color: GameColors.muted,
      fontSize: 9.5,
      letterSpacing: 1.5,
      fontWeight: FontWeight.w600,
    ),
  );

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: GameColors.background,
    fontFamily: 'SourceCodePro',
    textTheme: textTheme,
    colorScheme: const ColorScheme.dark(
      primary: GameColors.accent,
      secondary: GameColors.accent,
      surface: GameColors.panel,
      error: GameColors.danger,
      onPrimary: GameColors.text,
      onSecondary: GameColors.text,
      onSurface: GameColors.text,
      onError: GameColors.text,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GameColors.panelSoft,
        foregroundColor: GameColors.text,
        disabledBackgroundColor: GameColors.panelSoft.withValues(alpha: 0.45),
        disabledForegroundColor: GameColors.text.withValues(alpha: 0.45),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: GameColors.borderStrong),
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: GameColors.accent,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GameColors.panelSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GameColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GameColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GameColors.accent),
      ),
      labelStyle: const TextStyle(color: GameColors.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: GameColors.panel,
      contentTextStyle: textTheme.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
