// WI-13 (D-LineModel): the pure per-line terminal sequence math. `terminalReveal`
// returns one `TerminalLineState` per line: line i starts at offset[i] (from
// staggerOffsetFrames with a per-line lineGap), a Cmd types glyph-by-glyph after
// its start (glyphsRevealed), an Out appears whole at its start, line i+1 stays
// hidden while line i types, and the active Cmd shows a blinking caret while
// settled lines do not. Pure frame arithmetic, deterministic.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/terminal/render/terminal_layout.dart';
import 'package:fluvie/src/elements/terminal/terminal_line.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _scope = TimeScopeData(startFrame: 0, durationFrames: 600, fps: 30);

const _lines = [
  TerminalLine.cmd('npm i'), // 5 glyphs
  TerminalLine.out('added 120 packages'),
];

/// `terminalReveal` with the shared scope and a typing speed / line gap in frames.
List<TerminalLineState> _reveal(
  int elapsed, {
  List<TerminalLine> lines = _lines,
  int typingFrames = 2,
  int lineGapFrames = 30,
}) => terminalReveal(
  lines: lines,
  elapsed: elapsed,
  typingSpeed: Time.frames(typingFrames),
  lineGap: Time.frames(lineGapFrames),
  scope: _scope,
);

void main() {
  group('terminalReveal line starts', () {
    test('returns one state per line', () {
      expect(_reveal(0), hasLength(2));
    });

    test('line 0 starts at offset 0, line 1 at the lineGap', () {
      // At elapsed 0, only line 0 has started; line 1 (start = 30) is hidden.
      final at0 = _reveal(0);
      expect(at0[0].started, isTrue);
      expect(at0[1].started, isFalse);
      expect(at0[1].visibleGlyphs, 0);
    });

    test('an empty line list yields an empty result', () {
      expect(_reveal(0, lines: const []), isEmpty);
    });
  });

  group('terminalReveal cmd typing', () {
    test('a Cmd types glyph-by-glyph after its start', () {
      // 2 frames/glyph; at elapsed 4 -> 2 glyphs of "npm i".
      expect(_reveal(4)[0].visibleGlyphs, 2);
    });

    test('a Cmd shows all its glyphs once its reveal time has passed', () {
      // "npm i" is 5 glyphs * 2 frames = 10 frames.
      expect(_reveal(10)[0].visibleGlyphs, 5);
      expect(_reveal(100)[0].visibleGlyphs, 5);
    });

    test('the active Cmd shows a blinking caret', () {
      // At elapsed 0 (first half of the 16-frame period) the caret is lit.
      expect(_reveal(0)[0].caretOn, isTrue);
      // At elapsed 8 (second half) it is dark.
      expect(_reveal(8)[0].caretOn, isFalse);
    });

    test('a settled (fully typed) Cmd shows no caret', () {
      // After the command is fully typed it is settled; no caret.
      expect(_reveal(100)[0].caretOn, isFalse);
    });
  });

  group('terminalReveal out streaming', () {
    test('an Out appears whole at its start, not glyph-by-glyph', () {
      // Line 1 (Out) starts at 30; at elapsed 30 it is fully visible at once.
      final state = _reveal(30)[1];
      expect(state.started, isTrue);
      expect(state.visibleGlyphs, 'added 120 packages'.length);
    });

    test('an Out never shows a caret', () {
      expect(_reveal(40)[1].caretOn, isFalse);
    });

    test('line i+1 stays hidden while line i is still typing', () {
      // With lineGap < typing time, line 0 types past line 1's start; but the
      // gating keeps line 1 hidden until line 0 settles.
      const fast = [TerminalLine.cmd('aaaaaaaaaa'), TerminalLine.out('x')];
      // line 0 = 10 glyphs * 2 = 20 frames to type; lineGap 5 -> line 1 start 5.
      final mid = terminalReveal(
        lines: fast,
        elapsed: 8,
        typingSpeed: const Time.frames(2),
        lineGap: const Time.frames(5),
        scope: _scope,
      );
      expect(mid[0].visibleGlyphs, lessThan(10)); // still typing
      expect(mid[1].started, isFalse); // gated until line 0 settles
    });
  });

  group('terminalReveal determinism', () {
    test('identical inputs return identical state', () {
      expect(_reveal(4), _reveal(4));
    });
  });

  group('TerminalLineState value semantics', () {
    test('is value-equal with a stable hashCode and a readable toString', () {
      const a = TerminalLineState(started: true, visibleGlyphs: 3, caretOn: true);
      const b = TerminalLineState(started: true, visibleGlyphs: 3, caretOn: true);
      const different = TerminalLineState(started: true, visibleGlyphs: 4, caretOn: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(different));
      expect(a.toString(), contains('visibleGlyphs: 3'));
    });

    test('the hidden constant carries no started state', () {
      expect(TerminalLineState.hidden.started, isFalse);
      expect(TerminalLineState.hidden.visibleGlyphs, 0);
      expect(TerminalLineState.hidden.caretOn, isFalse);
    });
  });
}
