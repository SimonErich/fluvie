import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/reveal/glyph_reveal.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:meta/meta.dart' show immutable;

/// How a `Code` element reveals its source over its window: all at once, glyph
/// by glyph, or whole line by whole line.
///
/// A sealed value type, mirroring `Stagger`: the `Code` constructor stays one
/// `reveal:` parameter wide and the reveal math is one `switch` over the variant
/// in [resolveCodeReveal]. Each timed variant carries a [Time] that resolves
/// against the element window (like `Typewriter.speed`), so a relative speed
/// scales with the scene.
@immutable
sealed class CodeReveal {
  const CodeReveal();

  /// Reveals the joined source glyph by glyph at [speed] frames per glyph.
  const factory CodeReveal.typing(Time speed) = TypingReveal;

  /// Reveals whole lines in sequence: line `i` appears at `elapsed >= i x
  /// perLine`.
  const factory CodeReveal.lineByLine(Time perLine) = LineByLineReveal;

  /// Reveals every glyph immediately (the default).
  static const CodeReveal instant = InstantReveal._();
}

/// The [CodeReveal.instant] variant: everything is visible from frame 0.
final class InstantReveal extends CodeReveal {
  const InstantReveal._();

  @override
  bool operator ==(Object other) => other is InstantReveal;

  @override
  int get hashCode => (InstantReveal).hashCode;

  @override
  String toString() => 'CodeReveal.instant';
}

/// The [CodeReveal.typing] variant: glyph-by-glyph at [speed] frames per glyph.
final class TypingReveal extends CodeReveal {
  /// Creates a typed reveal at [speed] frames per glyph.
  // coverage:ignore-line: const-ctor artifact, equality/toString pinned by code_reveal_test
  const TypingReveal(this.speed);

  /// How long each glyph takes to appear; resolved against the element window.
  final Time speed;

  @override
  bool operator ==(Object other) => other is TypingReveal && other.speed == speed;

  @override
  int get hashCode => Object.hash(TypingReveal, speed);

  @override
  String toString() => 'CodeReveal.typing($speed)';
}

/// The [CodeReveal.lineByLine] variant: whole lines at [perLine] frames each.
final class LineByLineReveal extends CodeReveal {
  /// Creates a line-by-line reveal at [perLine] frames per line.
  // coverage:ignore-line: const-ctor artifact, equality/toString pinned by code_reveal_test
  const LineByLineReveal(this.perLine);

  /// How long each line waits before appearing; resolved against the window.
  final Time perLine;

  @override
  bool operator ==(Object other) => other is LineByLineReveal && other.perLine == perLine;

  @override
  int get hashCode => Object.hash(LineByLineReveal, perLine);

  @override
  String toString() => 'CodeReveal.lineByLine($perLine)';
}

/// The resolved reveal state at one frame: how many glyphs are visible and
/// whether the typing caret is lit.
@immutable
final class CodeRevealState {
  /// Creates a state with [visibleGlyphs] revealed and the caret [caretOn].
  const CodeRevealState({required this.visibleGlyphs, required this.caretOn});

  /// The number of leading glyphs of the joined source that are visible.
  final int visibleGlyphs;

  /// Whether a blinking caret should be drawn after the visible glyphs (only a
  /// [CodeReveal.typing] reveal that has not finished blinks).
  final bool caretOn;

  @override
  bool operator ==(Object other) =>
      other is CodeRevealState && other.visibleGlyphs == visibleGlyphs && other.caretOn == caretOn;

  @override
  int get hashCode => Object.hash(CodeRevealState, visibleGlyphs, caretOn);

  @override
  String toString() => 'CodeRevealState(visibleGlyphs: $visibleGlyphs, caretOn: $caretOn)';
}

/// The visible-glyph count and caret state for [reveal] at [elapsed] frames — a
/// pure function over the joined source.
///
/// [totalGlyphs] is the joined source length, [lineLengths] each line's glyph
/// count (including its trailing newline so the counts sum to [totalGlyphs]).
/// `instant` shows everything; `typing` floors `elapsed / perGlyph` via
/// [glyphsRevealed]; `lineByLine` shows every line whose start (`i x perLine`)
/// has passed. The caret lights only while a `typing` reveal is still running.
CodeRevealState resolveCodeReveal({
  required CodeReveal reveal,
  required int elapsed,
  required int totalGlyphs,
  required List<int> lineLengths,
  required TimeScopeData scope,
}) {
  switch (reveal) {
    case InstantReveal():
      return CodeRevealState(visibleGlyphs: totalGlyphs, caretOn: false);
    case TypingReveal(:final speed):
      final visible = glyphsRevealed(
        elapsed: elapsed,
        speed: speed,
        totalGlyphs: totalGlyphs,
        scope: scope,
      );
      final typing = visible < totalGlyphs;
      return CodeRevealState(visibleGlyphs: visible, caretOn: typing && caretBlinkOn(elapsed, 16));
    case LineByLineReveal(:final perLine):
      final perLineFrames = perLine.resolveFrames(scope);
      var visible = 0;
      for (var i = 0; i < lineLengths.length; i++) {
        final start = perLineFrames <= 0 ? 0 : i * perLineFrames;
        if (elapsed >= start) visible += lineLengths[i];
      }
      return CodeRevealState(visibleGlyphs: visible.clamp(0, totalGlyphs), caretOn: false);
  }
}
