// WI-16/17 coverage: the caption value types' toString and the equality
// branches the feature tests do not otherwise exercise (cue-word equality, the
// _sameWords length mismatch, the VTT/inline source equality, and the named
// constructors). These are pure value-data, so they are fully testable.

import 'package:flutter/painting.dart' show Alignment, Color, TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/caption_position.dart';
import 'package:fluvie/src/captions/caption_style.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/captions/caption_word.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/theme/caption_theme.dart';

void main() {
  group('toString', () {
    test('CaptionCue and CaptionCueWord name their content', () {
      final cue = CaptionCue('Hi', start: 0.0.seconds, end: 1.seconds);
      expect(cue.toString(), contains('Hi'));
      expect(CaptionCueWord('Hi', at: 0.0.seconds).toString(), contains('Hi'));
    });

    test('CaptionPosition, CaptionStyle, and CaptionTheme name their content', () {
      expect(const CaptionPosition.center().toString(), contains('CaptionPosition'));
      expect(const CaptionStyle.tikTok().toString(), contains('CaptionStyle'));
      expect(const CaptionTheme.standard().toString(), contains('CaptionTheme'));
    });

    test('CaptionSource variants name their origin', () {
      expect(const CaptionSource.srt('a').toString(), contains('a'));
      expect(const CaptionSource.vtt('b').toString(), contains('b'));
      expect(const CaptionSource.inline([]).toString(), contains('inline'));
    });

    test('Captions names its file or word count', () {
      expect(const Captions.fromSrt('x.srt').toString(), contains('x.srt'));
      expect(Captions.words(const []).toString(), contains('words'));
    });
  });

  group('equality edge cases', () {
    test('CaptionCue with differing word lists is not equal', () {
      final a = CaptionCue(
        't',
        start: 0.0.seconds,
        end: 1.seconds,
        words: [CaptionCueWord('a', at: 0.0.seconds)],
      );
      final b = CaptionCue('t', start: 0.0.seconds, end: 1.seconds);
      expect(a, isNot(b));
    });

    test('CaptionCue with same-length but differing words is not equal', () {
      // Same length, so _sameWords reaches the per-element compare and finds the
      // mismatch (the word text differs at index 0).
      final a = CaptionCue(
        't',
        start: 0.0.seconds,
        end: 1.seconds,
        words: [CaptionCueWord('a', at: 0.0.seconds)],
      );
      final b = CaptionCue(
        't',
        start: 0.0.seconds,
        end: 1.seconds,
        words: [CaptionCueWord('b', at: 0.0.seconds)],
      );
      expect(a, isNot(b));
    });

    test('CaptionPosition.custom is value-equal and distinct from a preset', () {
      expect(
        const CaptionPosition.custom(Alignment.topLeft),
        const CaptionPosition.custom(Alignment.topLeft),
      );
      expect(
        const CaptionPosition.custom(Alignment.topLeft),
        isNot(const CaptionPosition.center()),
      );
    });

    test('VttCaptionSource distinguishes its path', () {
      expect(const CaptionSource.vtt('a'), const CaptionSource.vtt('a'));
      expect(const CaptionSource.vtt('a'), isNot(const CaptionSource.vtt('b')));
    });

    test('inline sources differing in length are not equal', () {
      final a = CaptionSource.inline([CaptionWord('x', at: 0.0.seconds)]);
      const b = CaptionSource.inline([]);
      expect(a, isNot(b));
    });

    test('an inline cacheKey is a stable hash distinct per word set', () {
      final a = CaptionSource.inline([CaptionWord('hi', at: 0.0.seconds)]);
      final same = CaptionSource.inline([CaptionWord('hi', at: 0.0.seconds)]);
      final different = CaptionSource.inline([CaptionWord('bye', at: 0.0.seconds)]);
      expect(a.cacheKey, same.cacheKey); // canonical form is deterministic
      expect(a.cacheKey, isNot(different.cacheKey)); // different words → different key
      expect(a.cacheKey, isNotEmpty);
    });

    test('the named CaptionStyle constructor is value-equal', () {
      const custom = CaptionStyle(
        textStyle: TextStyle(),
        background: Color(0xFF000000),
        highlight: Color(0xFFFFFFFF),
      );
      expect(
        custom,
        const CaptionStyle(
          textStyle: TextStyle(),
          background: Color(0xFF000000),
          highlight: Color(0xFFFFFFFF),
        ),
      );
    });
  });
}
