// WI-17 (D-Captions, §17): the in-house WebVTT parser. VTT opens with a WEBVTT
// header, then cues with `HH:MM:SS.mmm --> HH:MM:SS.mmm` timecodes; an inline
// `<HH:MM:SS.mmm>` timestamp in the payload carries word-level timing. Pure,
// deterministic, no dependency; a malformed timecode throws naming the line.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/parse/vtt_parser.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_extensions.dart';

String _fixture() => File('test/captions/fixtures/sample.vtt').readAsStringSync();

void main() {
  group('parseVtt', () {
    test('skips the WEBVTT header and parses the cues', () {
      final cues = parseVtt(_fixture());
      expect(cues, hasLength(3));
      expect(cues.first.text, 'Hello world');
      expect(cues.first.start, 0.0.seconds);
      expect(cues.first.end, 2.0.seconds);
    });

    test('reads the HH:MM:SS.mmm timecode precisely', () {
      final cues = parseVtt(_fixture());
      expect(cues[1].start, 2.5.seconds);
      expect(cues[1].end, 5.0.seconds);
    });

    test('joins a multi-line cue with a newline', () {
      final cues = parseVtt(_fixture());
      expect(cues[1].text, 'This is a\ntwo-line cue');
    });

    test('preserves word-level timing from inline timestamps', () {
      final cues = parseVtt(_fixture());
      final karaoke = cues[2];
      expect(karaoke.text, 'Karaoke line here');
      expect(karaoke.words.map((w) => w.text), ['Karaoke', 'line', 'here']);
      expect(karaoke.words[0].at, 5.5.seconds);
      expect(karaoke.words[1].at, 5.9.seconds);
      expect(karaoke.words[2].at, 6.4.seconds);
    });

    test('a cue without inline timestamps carries no word timing', () {
      final cues = parseVtt(_fixture());
      expect(cues.first.words, isEmpty);
    });

    test('tolerates CRLF line endings', () {
      const crlf = 'WEBVTT\r\n\r\n00:00:00.000 --> 00:00:01.000\r\nHi\r\n';
      final cues = parseVtt(crlf);
      expect(cues, hasLength(1));
      expect(cues.single.text, 'Hi');
      expect(cues.single.end, 1.0.seconds);
    });

    test('a header-only file yields no cues', () {
      expect(parseVtt('WEBVTT\n\n'), isEmpty);
    });

    test('skips a cue identifier line before the timecode', () {
      const withId = 'WEBVTT\n\nintro\n00:00:00.000 --> 00:00:01.000\nHi\n';
      final cues = parseVtt(withId);
      expect(cues.single.text, 'Hi');
    });

    test('a cue with no timecode line throws naming it', () {
      const noTiming = 'WEBVTT\n\nonly an identifier\n';
      expect(
        () => parseVtt(noTiming),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            contains('no timecode'),
          ),
        ),
      );
    });

    test('a timecode line with no arrow throws naming it', () {
      const noArrow = 'WEBVTT\n\n00:00:00.000 00:00:01.000\nHi\n';
      expect(() => parseVtt(noArrow), throwsA(isA<FluvieTimingError>()));
    });

    test('a malformed timecode throws naming the offending line', () {
      const bad = 'WEBVTT\n\n00:00:00.000 --> nope\nHi\n';
      expect(
        () => parseVtt(bad),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            allOf(contains('nope'), contains('timecode')),
          ),
        ),
      );
    });

    test('returns CaptionCue values', () {
      expect(parseVtt(_fixture()).first, isA<CaptionCue>());
    });
  });
}
