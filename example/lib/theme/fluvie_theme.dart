import 'package:flutter/material.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:fluvie_example/theme/fluvie_shadows.dart';
import 'package:fluvie_example/theme/fluvie_text_theme.dart';

/// Builds the demo's content theme: light white panels, dark text, the brand
/// accent, and the landing's fonts.
///
/// The dark frame (app background, app bar, nav, film stage) opts into dark
/// styling locally: the app bar through [ThemeData.appBarTheme] here, the nav
/// through [buildFluvieDarkFrameTheme], and the stage through per-widget tokens.
ThemeData buildFluvieTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: FluvieColors.acc).copyWith(
    primary: FluvieColors.acc,
    secondary: FluvieColors.acc2,
    surface: FluvieColors.surface,
    onSurface: FluvieColors.ink,
    outline: FluvieColors.line,
  );
  final text = buildFluvieTextTheme(Brightness.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: FluvieColors.dark,
    dividerColor: FluvieColors.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: FluvieColors.dpanel,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: FluvieColors.acc,
      unselectedLabelColor: FluvieColors.muted,
      indicatorColor: FluvieColors.acc,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF6FAFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluvieRadii.button),
        borderSide: const BorderSide(color: FluvieColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluvieRadii.button),
        borderSide: const BorderSide(color: FluvieColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FluvieRadii.button),
        borderSide: const BorderSide(color: FluvieColors.acc, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FluvieColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluvieRadii.card)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FluvieColors.acc,
        foregroundColor: Colors.white,
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluvieRadii.button)),
      ),
    ),
  );
}

/// Builds the dark-frame theme for the left-nav subtree, so its [ListTile]s and
/// text default to light-on-dark over the dark glass panel.
ThemeData buildFluvieDarkFrameTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: FluvieColors.acc,
        brightness: Brightness.dark,
      ).copyWith(
        primary: FluvieColors.acc2,
        surface: FluvieColors.dpanel,
        onSurface: FluvieColors.dtext,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: buildFluvieTextTheme(Brightness.dark),
    hoverColor: FluvieColors.acc2.withValues(alpha: 0.1),
    listTileTheme: ListTileThemeData(
      selectedColor: FluvieColors.acc2,
      iconColor: FluvieColors.dmut,
      textColor: FluvieColors.dtext,
      selectedTileColor: FluvieColors.acc.withValues(alpha: 0.16),
    ),
  );
}
