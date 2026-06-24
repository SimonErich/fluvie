import 'package:flutter/material.dart';

import 'package:kitten_kit/src/theme/kitten_colors.dart';

/// The Material [ThemeData] every Kitten Mitten example app uses for its chrome,
/// built from [KittenColors] so the apps share one warm, playful look.
ThemeData kittenAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KittenColors.mitten,
    primary: KittenColors.mitten,
    secondary: KittenColors.tabby,
    surface: KittenColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: KittenColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: KittenColors.cream,
      foregroundColor: KittenColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KittenColors.mitten,
        foregroundColor: Colors.white,
        disabledBackgroundColor: KittenColors.line,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    cardTheme: CardThemeData(
      color: KittenColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: KittenColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KittenColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KittenColors.line),
      ),
    ),
  );
}
