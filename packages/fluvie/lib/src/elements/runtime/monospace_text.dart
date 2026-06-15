import 'dart:ui' show Color, TextDirection;

import 'package:flutter/painting.dart' show TextHeightBehavior, TextPainter, TextSpan, TextStyle;

/// Lays out a single line of monospace [text] in [color] and returns the
/// already-measured [TextPainter], the one idiom the code, terminal, and diff
/// painters share (DRY 2.1).
///
/// The painter is built with the requested [fontFamily] and [fontSize], a
/// left-to-right [TextDirection], and a default [TextHeightBehavior] (no
/// first-line ascent / last-line descent trimming), then laid out so the caller
/// can read [TextPainter.width] and `paint` it immediately. [opacity] (default
/// `1`, fully opaque) rides the glyph color as `color.withValues(alpha:
/// opacity)` — no `saveLayer`, so the draw stays capture-safe.
///
/// The caller owns the painter's lifecycle: `paint` it, capture its width, then
/// call [TextPainter.dispose].
TextPainter layoutMonospaceLine(
  String text,
  Color color, {
  required String fontFamily,
  required double fontSize,
  double opacity = 1,
}) => TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(
      color: color.withValues(alpha: opacity),
      fontFamily: fontFamily,
      fontSize: fontSize,
    ),
  ),
  textDirection: TextDirection.ltr,
  textHeightBehavior: const TextHeightBehavior(),
)..layout();
