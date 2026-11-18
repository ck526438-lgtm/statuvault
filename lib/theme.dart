import 'package:flutter/material.dart';

/// Couleurs tirées du logo Statuvault.
class SvColors {
  static const green = Color(0xFF4CEB62);
  static const greenDeep = Color(0xFF0A6B2E);
  static const bg = Color(0xFF04130A);
  static const surface = Color(0xFF0B2414);
  static const surfaceHi = Color(0xFF123520);
  static const text = Color(0xFFF2FFF4);
  static const muted = Color(0xFF8DB59A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SvColors.green,
    brightness: Brightness.dark,
  ).copyWith(
    primary: SvColors.green,
    onPrimary: const Color(0xFF02210B),
    secondary: SvColors.greenDeep,
    surface: SvColors.surface,
    onSurface: SvColors.text,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: SvColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: SvColors.bg,
      foregroundColor: SvColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: SvColors.green,
      unselectedLabelColor: SvColors.muted,
      indicatorColor: SvColors.green,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: SvColors.surfaceHi,
      contentTextStyle: TextStyle(color: SvColors.text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SvColors.green,
        foregroundColor: const Color(0xFF02210B),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
