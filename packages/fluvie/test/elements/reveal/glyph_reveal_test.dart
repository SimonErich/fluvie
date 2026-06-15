// WI-1 (D-Reveal): the promoted reveal-math module. `revealProgress` is the
// exact arithmetic the charts used (was `chartRevealProgress`); `glyphsRevealed`
// is the `Typewriter` floor arithmetic (byte-for-byte); `caretBlinkOn` is the
// `Typewriter` blink. `staggeredRevealProgress` is unchanged.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/reveal/glyph_reveal.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60);
const _offsetScope = TimeScopeData(fps: 30, startFrame: 30, durationFrames: 60);

void main() {
  group('revealProgress (was chartRevealProgress)', () {
    test('is 0 at the scope start', () {
      expect(revealProgress(0, _scope, const Time.frames(30)), 0.0);
    });

    test('is linear at the midpoint', () {
      expect(revealProgress(15, _scope, const Time.frames(30)), 0.5);
    });

    test('is 1 exactly at the reveal-end frame', () {
      expect(revealProgress(30, _scope, const Time.frames(30)), 1.0);
    });

    test('clamps to 1 past the reveal-end frame', () {
      expect(revealProgress(50, _scope, const Time.frames(30)), 1.0);
    });

    test('clamps to 0 before the scope start', () {
      expect(revealProgress(-5, _scope, const Time.frames(30)), 0.0);
    });

    test('returns 1.0 when the reveal resolves to zero frames', () {
      expect(revealProgress(0, _scope, Time.zero), 1.0);
    });

    test('returns 1.0 when the reveal resolves negative', () {
      expect(revealProgress(0, _scope, const Time.frames(-10)), 1.0);
    });

    test('counts elapsed from the scope start, not absolute frame 0', () {
      expect(revealProgress(45, _offsetScope, const Time.frames(30)), 0.5);
    });

    test('resolves a relative reveal against the scope window', () {
      expect(revealProgress(15, _scope, const Time.relative(0.5)), 0.5);
    });
  });

  group('glyphsRevealed (the Typewriter floor arithmetic)', () {
    test('reveals zero glyphs at the scope start', () {
      expect(
        glyphsRevealed(elapsed: 0, speed: const Time.frames(2), totalGlyphs: 10, scope: _scope),
        0,
      );
    });

    test('floors elapsed / perGlyph', () {
      // 2 frames per glyph; elapsed 7 -> floor(7/2) = 3.
      expect(
        glyphsRevealed(elapsed: 7, speed: const Time.frames(2), totalGlyphs: 10, scope: _scope),
        3,
      );
    });

    test('clamps to totalGlyphs once the whole string is revealed', () {
      expect(
        glyphsRevealed(elapsed: 100, speed: const Time.frames(2), totalGlyphs: 10, scope: _scope),
        10,
      );
    });

    test('clamps to 0 before the scope start (negative elapsed)', () {
      expect(
        glyphsRevealed(elapsed: -4, speed: const Time.frames(2), totalGlyphs: 10, scope: _scope),
        0,
      );
    });

    test('returns totalGlyphs on a zero-length speed', () {
      expect(
        glyphsRevealed(elapsed: 0, speed: Time.zero, totalGlyphs: 10, scope: _scope),
        10,
      );
    });

    test('returns totalGlyphs on a negative speed', () {
      expect(
        glyphsRevealed(elapsed: 0, speed: const Time.frames(-3), totalGlyphs: 10, scope: _scope),
        10,
      );
    });

    test('matches the Typewriter byte-for-byte at a mid frame', () {
      // Typewriter: revealed = (elapsed ~/ perGlyph).clamp(0, length).
      const elapsed = 9;
      const perGlyph = 2;
      const length = 20;
      final expected = (elapsed ~/ perGlyph).clamp(0, length);
      expect(
        glyphsRevealed(
          elapsed: elapsed,
          speed: const Time.frames(perGlyph),
          totalGlyphs: length,
          scope: _scope,
        ),
        expected,
      );
    });

    test('resolves a relative speed against the scope', () {
      // 0.1 of a 60-frame scope = 6 frames per glyph; elapsed 18 -> 3 glyphs.
      expect(
        glyphsRevealed(
          elapsed: 18,
          speed: const Time.relative(0.1),
          totalGlyphs: 10,
          scope: _scope,
        ),
        3,
      );
    });
  });

  group('caretBlinkOn (the Typewriter blink)', () {
    test('is on at the very start of a period', () {
      expect(caretBlinkOn(0, 16), isTrue);
    });

    test('is on through the first half of the period', () {
      expect(caretBlinkOn(7, 16), isTrue);
    });

    test('is off through the second half of the period', () {
      expect(caretBlinkOn(8, 16), isFalse);
      expect(caretBlinkOn(15, 16), isFalse);
    });

    test('is off before the scope start (negative elapsed)', () {
      expect(caretBlinkOn(-1, 16), isFalse);
    });

    test('matches the Typewriter expression byte-for-byte', () {
      const period = 16;
      for (var elapsed = -3; elapsed < 40; elapsed++) {
        final expected = elapsed >= 0 && elapsed % period < period ~/ 2;
        expect(caretBlinkOn(elapsed, period), expected, reason: 'elapsed $elapsed');
      }
    });
  });

  group('staggeredRevealProgress (unchanged)', () {
    test('returns one clamped progress per segment offset', () {
      final result = staggeredRevealProgress(
        elapsed: 10,
        offsets: const [0, 5, 10],
        perSegmentFrames: 10,
      );
      expect(result, [1.0, 0.5, 0.0]);
    });

    test('an empty offset list yields an empty result', () {
      expect(
        staggeredRevealProgress(elapsed: 5, offsets: const [], perSegmentFrames: 10),
        isEmpty,
      );
    });

    test('a zero-length per-segment span yields 1.0 for started segments', () {
      final result = staggeredRevealProgress(
        elapsed: 5,
        offsets: const [0, 10],
        perSegmentFrames: 0,
      );
      expect(result[0], 1.0);
      expect(result[1], 0.0);
    });
  });
}
