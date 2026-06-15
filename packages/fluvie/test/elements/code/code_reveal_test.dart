// WI-6 (D-CodeReveal): the sealed CodeReveal value type and its pure resolver.
// `instant` shows everything; `typing(speed)` floors glyphs; `lineByLine(perLine)`
// shows whole lines (line i visible at elapsed >= i x perLine).

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/code/code_reveal.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 120);

void main() {
  group('CodeReveal value equality', () {
    test('instant is a const singleton equal to itself', () {
      expect(CodeReveal.instant, CodeReveal.instant);
    });

    test('typing is value-equal by speed', () {
      expect(
        const CodeReveal.typing(Time.frames(2)),
        const CodeReveal.typing(Time.frames(2)),
      );
      expect(
        const CodeReveal.typing(Time.frames(2)),
        isNot(const CodeReveal.typing(Time.frames(3))),
      );
    });

    test('lineByLine is value-equal by perLine', () {
      expect(
        const CodeReveal.lineByLine(Time.frames(6)),
        const CodeReveal.lineByLine(Time.frames(6)),
      );
      expect(
        const CodeReveal.lineByLine(Time.frames(6)),
        isNot(const CodeReveal.lineByLine(Time.frames(9))),
      );
    });

    test('the three variants are mutually unequal', () {
      expect(CodeReveal.instant, isNot(const CodeReveal.typing(Time.frames(2))));
      expect(CodeReveal.instant, isNot(const CodeReveal.lineByLine(Time.frames(2))));
    });

    test('each variant has a stable hashCode and a readable toString', () {
      expect(CodeReveal.instant.hashCode, CodeReveal.instant.hashCode);
      expect(CodeReveal.instant.toString(), 'CodeReveal.instant');
      expect(
        const CodeReveal.typing(Time.frames(2)).hashCode,
        const CodeReveal.typing(Time.frames(2)).hashCode,
      );
      expect(const CodeReveal.typing(Time.frames(2)).toString(), contains('typing'));
      expect(
        const CodeReveal.lineByLine(Time.frames(6)).hashCode,
        const CodeReveal.lineByLine(Time.frames(6)).hashCode,
      );
      expect(const CodeReveal.lineByLine(Time.frames(6)).toString(), contains('lineByLine'));
    });
  });

  group('CodeRevealState value type', () {
    test('is value-equal by field with a stable hashCode and toString', () {
      const a = CodeRevealState(visibleGlyphs: 5, caretOn: true);
      const b = CodeRevealState(visibleGlyphs: 5, caretOn: true);
      const c = CodeRevealState(visibleGlyphs: 6, caretOn: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('CodeRevealState'));
    });
  });

  group('resolveCodeReveal', () {
    const lineLengths = [10, 6, 8]; // 3 lines, 24 glyphs total.
    const totalGlyphs = 24;

    test('instant reveals every glyph at frame 0', () {
      final state = resolveCodeReveal(
        reveal: CodeReveal.instant,
        elapsed: 0,
        totalGlyphs: totalGlyphs,
        lineLengths: lineLengths,
        scope: _scope,
      );
      expect(state.visibleGlyphs, totalGlyphs);
      expect(state.caretOn, isFalse);
    });

    test('typing floors glyphs over the joined source', () {
      // 2 frames per glyph; elapsed 10 -> 5 glyphs.
      final state = resolveCodeReveal(
        reveal: const CodeReveal.typing(Time.frames(2)),
        elapsed: 10,
        totalGlyphs: totalGlyphs,
        lineLengths: lineLengths,
        scope: _scope,
      );
      expect(state.visibleGlyphs, 5);
    });

    test('typing reveals all glyphs at the end and shows a caret while typing', () {
      final end = resolveCodeReveal(
        reveal: const CodeReveal.typing(Time.frames(2)),
        elapsed: 1000,
        totalGlyphs: totalGlyphs,
        lineLengths: lineLengths,
        scope: _scope,
      );
      expect(end.visibleGlyphs, totalGlyphs);
      // Caret blinks while typing (frame 0 is the lit half of the period).
      final start = resolveCodeReveal(
        reveal: const CodeReveal.typing(Time.frames(2)),
        elapsed: 0,
        totalGlyphs: totalGlyphs,
        lineLengths: lineLengths,
        scope: _scope,
      );
      expect(start.caretOn, isTrue);
    });

    test('lineByLine shows line 0 only at an early frame', () {
      // perLine 6 frames; elapsed 3 -> only line 0 (its 10 glyphs).
      final state = resolveCodeReveal(
        reveal: const CodeReveal.lineByLine(Time.frames(6)),
        elapsed: 3,
        totalGlyphs: totalGlyphs,
        lineLengths: lineLengths,
        scope: _scope,
      );
      expect(state.visibleGlyphs, 10);
    });

    test('lineByLine reveals line i at elapsed >= i x perLine', () {
      // elapsed 6 -> lines 0 and 1 (10 + 6 = 16 glyphs).
      final two = resolveCodeReveal(
        reveal: const CodeReveal.lineByLine(Time.frames(6)),
        elapsed: 6,
        totalGlyphs: totalGlyphs,
        lineLengths: lineLengths,
        scope: _scope,
      );
      expect(two.visibleGlyphs, 16);
      // elapsed 12 -> all 3 lines.
      final all = resolveCodeReveal(
        reveal: const CodeReveal.lineByLine(Time.frames(6)),
        elapsed: 12,
        totalGlyphs: totalGlyphs,
        lineLengths: lineLengths,
        scope: _scope,
      );
      expect(all.visibleGlyphs, totalGlyphs);
    });
  });
}
