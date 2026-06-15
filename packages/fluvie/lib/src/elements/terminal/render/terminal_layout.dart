/// @docImport 'package:fluvie/src/elements/reveal/glyph_reveal.dart';
/// @docImport 'package:fluvie/src/elements/terminal/terminal.dart';
library;

import 'package:fluvie/src/animation/stagger/stagger_offsets.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/reveal/glyph_reveal.dart';
import 'package:fluvie/src/elements/terminal/terminal_line.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:meta/meta.dart' show immutable;

/// The blink period (in frames) of the typing caret, pinned to match the
/// `Typewriter` / `Code` blink so every typed-reveal element blinks identically.
const int _caretPeriod = 16;

/// The resolved reveal state of one terminal line at one frame: whether it has
/// [started], how many leading glyphs are visible, and whether its blinking
/// caret is lit.
@immutable
final class TerminalLineState {
  /// Creates a state for a line that has [started] with [visibleGlyphs] revealed
  /// and the caret [caretOn].
  const TerminalLineState({
    required this.started,
    required this.visibleGlyphs,
    required this.caretOn,
  });

  /// The hidden state of a line whose turn has not yet arrived.
  static const TerminalLineState hidden = TerminalLineState(
    started: false,
    visibleGlyphs: 0,
    caretOn: false,
  );

  /// Whether this line's turn has arrived (its prompt, if any, is showing).
  final bool started;

  /// The number of leading glyphs of the line's text that are visible. A `Cmd`
  /// counts up glyph by glyph; an `Out` jumps to its full length once started.
  final int visibleGlyphs;

  /// Whether a blinking caret is drawn after the visible glyphs — only on the
  /// active (still-typing) `Cmd` line.
  final bool caretOn;

  @override
  bool operator ==(Object other) =>
      other is TerminalLineState &&
      other.started == started &&
      other.visibleGlyphs == visibleGlyphs &&
      other.caretOn == caretOn;

  @override
  int get hashCode => Object.hash(TerminalLineState, started, visibleGlyphs, caretOn);

  @override
  String toString() =>
      'TerminalLineState(started: $started, visibleGlyphs: $visibleGlyphs, caretOn: $caretOn)';
}

/// The per-line reveal state of [lines] at [elapsed] frames — a pure function
/// of `(lines, elapsed, speeds, scope)`.
///
/// Each line is sequenced from a [staggerOffsetFrames] base offset stepped by
/// [lineGap] (lines = children), then gated so a line never starts before the
/// previous line has settled: a `Cmd` settles once every glyph is typed (its
/// length × [typingSpeed]), an `Out` settles the frame it starts. A started
/// `Cmd` types glyph by glyph via [glyphsRevealed] and shows a blinking caret
/// ([caretBlinkOn]) until it settles; a started `Out` shows its whole text at
/// once with no caret. Identical inputs always return identical states.
List<TerminalLineState> terminalReveal({
  required List<TerminalLine> lines,
  required int elapsed,
  required Time typingSpeed,
  required Time lineGap,
  required TimeScopeData scope,
}) {
  if (lines.isEmpty) return const [];
  final offsets = staggerOffsetFrames(
    stagger: Stagger.each(lineGap),
    childCount: lines.length,
    scope: scope,
  );
  final perGlyph = typingSpeed.resolveFrames(scope);
  final states = <TerminalLineState>[];
  var previousSettle = 0;
  for (var i = 0; i < lines.length; i++) {
    final start = offsets[i] > previousSettle ? offsets[i] : previousSettle;
    final line = lines[i];
    final length = line.text.length;
    final typeFrames = perGlyph <= 0 ? 0 : length * perGlyph;
    previousSettle = line is TerminalCmd ? start + typeFrames : start;
    states.add(_lineState(line, elapsed - start, typingSpeed, length, scope));
  }
  return states;
}

/// The state of one [line] [sinceStart] frames after its (gated) start.
TerminalLineState _lineState(
  TerminalLine line,
  int sinceStart,
  Time typingSpeed,
  int length,
  TimeScopeData scope,
) {
  if (sinceStart < 0) return TerminalLineState.hidden;
  return switch (line) {
    TerminalCmd() => _cmdState(sinceStart, typingSpeed, length, scope),
    TerminalOut() => TerminalLineState(started: true, visibleGlyphs: length, caretOn: false),
  };
}

/// The typing state of a `Cmd` line: floored glyphs via the shared
/// [glyphsRevealed] and a caret that blinks until the command is fully typed.
TerminalLineState _cmdState(int sinceStart, Time typingSpeed, int length, TimeScopeData scope) {
  final visible = glyphsRevealed(
    elapsed: sinceStart,
    speed: typingSpeed,
    totalGlyphs: length,
    scope: scope,
  );
  final typing = visible < length;
  return TerminalLineState(
    started: true,
    visibleGlyphs: visible,
    caretOn: typing && caretBlinkOn(sinceStart, _caretPeriod),
  );
}
