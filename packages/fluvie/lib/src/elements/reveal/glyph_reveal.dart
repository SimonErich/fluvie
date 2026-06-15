/// @docImport 'package:fluvie/src/elements/typewriter.dart';
library;

import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The number of glyphs revealed at [elapsed] frames into a typed reveal of
/// [totalGlyphs] glyphs at [speed] frames per glyph.
///
/// This is the exact `Typewriter` floor arithmetic, promoted so `Typewriter`,
/// `Code` typing, and `Terminal` typed commands share one primitive and cannot
/// drift: the count is `floor(elapsed / perGlyph)` clamped to
/// `[0, totalGlyphs]`, where `perGlyph` is [speed] resolved against [scope]. A
/// zero- or negative-length [speed] reveals every glyph at once (returns
/// [totalGlyphs]) instead of dividing by zero. A partial glyph never shows — the
/// floor means a glyph appears only once its whole reveal time has passed, so
/// the reveal is byte-identical on every render.
int glyphsRevealed({
  required int elapsed,
  required Time speed,
  required int totalGlyphs,
  required TimeScopeData scope,
}) {
  final perGlyph = speed.resolveFrames(scope);
  if (perGlyph <= 0) return totalGlyphs;
  return (elapsed ~/ perGlyph).clamp(0, totalGlyphs);
}

/// Whether a blinking caret is lit at [elapsed] frames for a blink [period].
///
/// The caret is on for the first half of each [period] and off for the second,
/// and always off before the scope start ([elapsed] negative). This is the exact
/// `Typewriter` blink expression, promoted so every typed-reveal element blinks
/// identically — pure frame arithmetic, deterministic across machines.
bool caretBlinkOn(int elapsed, int period) => elapsed >= 0 && elapsed % period < period ~/ 2;
