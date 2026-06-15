// WI-16 (D-Captions-types, §17): the CaptionCue value type — text plus its
// start/end window, value-equal so two parses of one file produce equal cues.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/time_extensions.dart';

void main() {
  group('CaptionCue', () {
    test('carries text, start, and end verbatim', () {
      final cue = CaptionCue('Hello world', start: 0.5.seconds, end: 2.seconds);
      expect(cue.text, 'Hello world');
      expect(cue.start, 0.5.seconds);
      expect(cue.end, 2.seconds);
    });

    test('is value-equal with a matching hashCode', () {
      final a = CaptionCue('Hello', start: 0.0.seconds, end: 1.seconds);
      final b = CaptionCue('Hello', start: 0.0.seconds, end: 1.seconds);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs by text, start, or end', () {
      final base = CaptionCue('Hello', start: 0.0.seconds, end: 1.seconds);
      expect(base, isNot(CaptionCue('world', start: 0.0.seconds, end: 1.seconds)));
      expect(base, isNot(CaptionCue('Hello', start: 0.1.seconds, end: 1.seconds)));
      expect(base, isNot(CaptionCue('Hello', start: 0.0.seconds, end: 2.seconds)));
    });

    test('carries optional word-level timing when present', () {
      final cue = CaptionCue(
        'Hello world',
        start: 0.0.seconds,
        end: 1.seconds,
        words: [
          CaptionCueWord('Hello', at: 0.0.seconds),
          CaptionCueWord('world', at: 0.4.seconds),
        ],
      );
      expect(cue.words, hasLength(2));
      expect(cue.words.first.text, 'Hello');
      expect(cue.words.first.at, 0.0.seconds);
    });

    test('defaults to no word-level timing', () {
      final cue = CaptionCue('Hello', start: 0.0.seconds, end: 1.seconds);
      expect(cue.words, isEmpty);
    });

    test('toString names the text and window', () {
      final cue = CaptionCue('Hello', start: 0.0.seconds, end: 1.seconds);
      expect(cue.toString(), contains('Hello'));
    });
  });

  group('CaptionCueWord', () {
    test('is value-equal with a matching hashCode', () {
      expect(
        CaptionCueWord('Hi', at: 0.2.seconds),
        CaptionCueWord('Hi', at: 0.2.seconds),
      );
      expect(
        CaptionCueWord('Hi', at: 0.2.seconds).hashCode,
        CaptionCueWord('Hi', at: 0.2.seconds).hashCode,
      );
      expect(
        CaptionCueWord('Hi', at: 0.2.seconds),
        isNot(CaptionCueWord('Hi', at: 0.3.seconds)),
      );
    });
  });
}
