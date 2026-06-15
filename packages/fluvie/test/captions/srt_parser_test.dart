// WI-17 (D-Captions, §17): the in-house SRT parser. SubRip is line-oriented:
// an index line, an `HH:MM:SS,mmm --> HH:MM:SS,mmm` timecode line, then one or
// more text lines, blocks separated by a blank line. Pure, deterministic, no
// dependency; a malformed timecode throws naming the line.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/parse/srt_parser.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_extensions.dart';

String _fixture() => File('test/captions/fixtures/sample.srt').readAsStringSync();

void main() {
  group('parseSrt', () {
    test('parses an index, timecode, and text into a cue', () {
      final cues = parseSrt(_fixture());
      expect(cues, hasLength(2));
      expect(cues.first.text, 'Hello world');
      expect(cues.first.start, 0.0.seconds);
      expect(cues.first.end, 2.0.seconds);
    });

    test('reads the HH:MM:SS,mmm timecode precisely', () {
      final cues = parseSrt(_fixture());
      expect(cues[1].start, 2.5.seconds);
      expect(cues[1].end, 5.0.seconds);
    });

    test('joins a multi-line cue with a newline', () {
      final cues = parseSrt(_fixture());
      expect(cues[1].text, 'This is a\ntwo-line cue');
    });

    test('tolerates CRLF line endings', () {
      const crlf = '1\r\n00:00:00,000 --> 00:00:01,000\r\nHi\r\n';
      final cues = parseSrt(crlf);
      expect(cues, hasLength(1));
      expect(cues.single.text, 'Hi');
      expect(cues.single.end, 1.0.seconds);
    });

    test('tolerates a leading blank line and trailing whitespace', () {
      const messy = '\n\n1\n00:00:00,000 --> 00:00:01,500\nHi\n\n';
      final cues = parseSrt(messy);
      expect(cues, hasLength(1));
      expect(cues.single.end, 1.5.seconds);
    });

    test('parses hours, minutes, seconds, and milliseconds together', () {
      const block = '1\n01:02:03,400 --> 01:02:04,500\nLate\n';
      final cues = parseSrt(block);
      const start = 1 * 3600 + 2 * 60 + 3 + 0.4;
      expect(cues.single.start, start.seconds);
    });

    test('an empty source yields no cues', () {
      expect(parseSrt(''), isEmpty);
      expect(parseSrt('   \n\n  '), isEmpty);
    });

    test('a block with only an index (no timecode) throws naming it', () {
      expect(
        () => parseSrt('42\n'),
        throwsA(
          isA<FluvieTimingError>().having((e) => e.message, 'message', contains('no timecode')),
        ),
      );
    });

    test('a timecode line with no arrow throws naming it', () {
      expect(
        () => parseSrt('1\n00:00:00,000 00:00:01,000\nHi\n'),
        throwsA(isA<FluvieTimingError>()),
      );
    });

    test('a malformed timecode throws naming the offending line', () {
      const bad = '1\n00:00:00 --> bogus\nHi\n';
      expect(
        () => parseSrt(bad),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            allOf(contains('bogus'), contains('timecode')),
          ),
        ),
      );
    });

    test('returns CaptionCue values', () {
      expect(parseSrt(_fixture()).first, isA<CaptionCue>());
    });
  });
}
