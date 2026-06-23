import 'package:flutter/material.dart';

/// The bundled monospace family (JetBrains Mono) for code, filenames, and
/// numeric labels.
const fluvieMonoFamily = 'JetBrains Mono';

/// A JetBrains Mono text style for code, filenames, and numeric data.
TextStyle fluvieMono({
  double fontSize = 12,
  Color? color,
  FontWeight? fontWeight,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: fluvieMonoFamily,
  fontSize: fontSize,
  color: color,
  fontWeight: fontWeight,
  height: height,
  letterSpacing: letterSpacing,
);

/// Builds the Fluvie text theme for [brightness] from the bundled landing fonts:
/// Manrope for body and labels, Sora for the display, headline, and title roles.
///
/// Code uses [fluvieMono] directly in the editor, not this text theme.
TextTheme buildFluvieTextTheme(Brightness brightness) {
  final base = ThemeData(brightness: brightness).textTheme.apply(fontFamily: 'Manrope');
  TextStyle? sora(TextStyle? style, FontWeight weight, [double spacing = 0]) =>
      style?.copyWith(fontFamily: 'Sora', fontWeight: weight, letterSpacing: spacing);
  return base.copyWith(
    displayLarge: sora(base.displayLarge, FontWeight.w800, -1),
    displayMedium: sora(base.displayMedium, FontWeight.w800, -1),
    displaySmall: sora(base.displaySmall, FontWeight.w700, -0.5),
    headlineLarge: sora(base.headlineLarge, FontWeight.w700, -0.5),
    headlineMedium: sora(base.headlineMedium, FontWeight.w700),
    headlineSmall: sora(base.headlineSmall, FontWeight.w700),
    titleLarge: sora(base.titleLarge, FontWeight.w700),
    titleMedium: sora(base.titleMedium, FontWeight.w600),
    titleSmall: sora(base.titleSmall, FontWeight.w600),
  );
}
