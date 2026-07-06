import 'package:flutter/material.dart';

import '../../game/domain/models.dart';

/// ---------------------------------------------------------------------------
/// Tactical Command — design system
///
/// A single source of truth for the game's visual language. Colors are split
/// into structural tokens (surfaces, text, accents) and *mechanic* tokens
/// (one accent per damage type) so the UI teaches the game's systems through
/// consistent color. Reused across every screen, the HUD, and the store.
/// ---------------------------------------------------------------------------
class GameColors {
  // Structure / surfaces.
  static const background = Color(0xFF070D18);
  static const backgroundSoft = Color(0xFF0C1525);
  static const panel = Color(0xFF101D31);
  static const panelSoft = Color(0xFF16253C);
  static const panelStrong = Color(0xFF1E3251);
  static const panelGlass = Color(0xCC0F1B2E);

  // Lines / strokes.
  static const border = Color(0x2459B0FF);
  static const borderStrong = Color(0x5559B0FF);
  static const grid = Color(0x14A8D4FF);

  // Text.
  static const text = Color(0xFFEAF2FE);
  static const muted = Color(0xFF8AA6CC);
  static const faint = Color(0xFF55708F);

  // Accents.
  static const accent = Color(0xFF46A6FF);
  static const accentBright = Color(0xFF7FC4FF);
  static const accentSoft = Color(0x2946A6FF);
  static const success = Color(0xFF54E0A0);
  static const warning = Color(0xFFFFB347);
  static const danger = Color(0xFFFF6F6B);

  // Economy / progression.
  static const gold = Color(0xFFFFD24A);
  static const crystal = Color(0xFF79E2FF);
  static const cash = Color(0xFF6FE89A);
  static const health = Color(0xFFFF7E84);

  /// One signature color per damage type. Reused on tower chips, the store,
  /// selection cards, and intel so players learn counters by color.
  static const Map<DamageType, Color> damageType = <DamageType, Color>{
    DamageType.physical: Color(0xFFC2CCDA),
    DamageType.energy: Color(0xFF54D6FF),
    DamageType.explosion: Color(0xFFFF8A45),
    DamageType.poison: Color(0xFFA6E24B),
    DamageType.slow: Color(0xFF62A8F0),
    DamageType.piercing: Color(0xFFC08CFF),
    DamageType.regen: Color(0xFFFF86B4),
  };

  static Color forDamageType(DamageType type) =>
      damageType[type] ?? accent;
}

/// Reusable gradients for backgrounds and accent fills.
class GameGradients {
  static const LinearGradient screen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF060B14), Color(0xFF0B1A2C), Color(0xFF081320)],
    stops: <double>[0.0, 0.55, 1.0],
  );

  static const LinearGradient panel = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF13243C), Color(0xFF0D1A2C)],
  );

  static const LinearGradient panelStrong = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF1A3050), Color(0xFF112138)],
  );

  static LinearGradient accent(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color.lerp(color, Colors.white, 0.18)!,
      Color.lerp(color, Colors.black, 0.12)!,
    ],
  );
}

/// Standard spacing + radius scale so layouts stay rhythmic.
class GameSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

/// A small label style used for the "section eyebrow" headers everywhere.
const TextStyle kEyebrowStyle = TextStyle(
  color: GameColors.accent,
  fontSize: 9.5,
  letterSpacing: 2.6,
  fontWeight: FontWeight.w800,
);

ThemeData buildGameTheme() {
  const textTheme = TextTheme(
    headlineMedium: TextStyle(
      color: GameColors.text,
      fontWeight: FontWeight.w800,
      fontSize: 20,
      height: 1.0,
    ),
    titleMedium: TextStyle(
      color: GameColors.text,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    ),
    bodyMedium: TextStyle(color: GameColors.text, fontSize: 12, height: 1.35),
    bodySmall: TextStyle(color: GameColors.muted, fontSize: 10.5, height: 1.4),
    labelMedium: TextStyle(
      color: GameColors.muted,
      fontSize: 9.5,
      letterSpacing: 1.5,
      fontWeight: FontWeight.w700,
    ),
  );

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: GameColors.background,
    fontFamily: 'SourceCodePro',
    textTheme: textTheme,
    splashFactory: InkRipple.splashFactory,
    colorScheme: const ColorScheme.dark(
      primary: GameColors.accent,
      secondary: GameColors.accentBright,
      surface: GameColors.panel,
      error: GameColors.danger,
      onPrimary: Color(0xFF04121F),
      onSecondary: Color(0xFF04121F),
      onSurface: GameColors.text,
      onError: GameColors.text,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GameColors.panelSoft,
        foregroundColor: GameColors.text,
        disabledBackgroundColor: GameColors.panelSoft.withValues(alpha: 0.45),
        disabledForegroundColor: GameColors.text.withValues(alpha: 0.45),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameSpace.radiusMd),
          side: const BorderSide(color: GameColors.borderStrong),
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GameColors.accent,
        foregroundColor: const Color(0xFF04121F),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GameColors.text,
        side: const BorderSide(color: GameColors.borderStrong),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: GameColors.accentBright,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: GameColors.text,
        side: const BorderSide(color: GameColors.borderStrong),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        return states.contains(WidgetState.selected)
            ? GameColors.accentBright
            : GameColors.faint;
      }),
      trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        return states.contains(WidgetState.selected)
            ? GameColors.accentSoft
            : GameColors.panelStrong;
      }),
      trackOutlineColor: WidgetStateProperty.all(GameColors.border),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GameColors.panelSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        borderSide: const BorderSide(color: GameColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        borderSide: const BorderSide(color: GameColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        borderSide: const BorderSide(color: GameColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: GameColors.muted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GameColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameSpace.radiusLg),
        side: const BorderSide(color: GameColors.borderStrong),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: GameColors.panelStrong,
      contentTextStyle: textTheme.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameSpace.radiusMd),
        side: const BorderSide(color: GameColors.borderStrong),
      ),
    ),
  );
}
