// WI-19 (D-CaptionsRender, §17): the word-pop math reuses the shared stagger
// and the Animation progress pipeline (the DRY guardrail) — no bespoke caption
// animation. Per-word start frames come from word timing (or a fixed stagger),
// and the pop scale is MotionRunner.progress on a pop spring.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/runtime/caption_word_pop.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);

void main() {
  group('wordStartFrames', () {
    test('uses each word timing when the cue carries it', () {
      final cue = CaptionCue(
        'Hello world',
        start: 0.0.seconds,
        end: 2.seconds,
        words: [
          CaptionCueWord('Hello', at: 0.0.seconds),
          CaptionCueWord('world', at: 0.5.seconds),
        ],
      );
      expect(wordStartFrames(cue, _scope), [0, 15]);
    });

    test('falls back to a fixed stagger from the cue start when no word timing', () {
      final cue = CaptionCue('one two three', start: 1.seconds, end: 3.seconds);
      final frames = wordStartFrames(cue, _scope);
      expect(frames, hasLength(3));
      expect(frames.first, 30); // the cue start frame
      // strictly increasing: each word lags the previous by the stagger gap
      expect(frames[1], greaterThan(frames[0]));
      expect(frames[2], greaterThan(frames[1]));
    });

    test('an empty cue yields no word frames', () {
      final cue = CaptionCue('', start: 0.0.seconds, end: 1.seconds);
      expect(wordStartFrames(cue, _scope), isEmpty);
    });
  });

  group('wordPopScale', () {
    test('is 0 before the word starts', () {
      expect(wordPopScale(frame: 5, wordStartFrame: 10, fps: 30), 0);
    });

    test('rises toward 1 across the pop window', () {
      final early = wordPopScale(frame: 11, wordStartFrame: 10, fps: 30);
      final later = wordPopScale(frame: 16, wordStartFrame: 10, fps: 30);
      expect(early, greaterThan(0));
      expect(later, greaterThan(early));
    });

    test('settles to exactly 1 well after the word starts', () {
      expect(wordPopScale(frame: 200, wordStartFrame: 10, fps: 30), 1);
    });

    test('is deterministic (same inputs, same scale)', () {
      expect(
        wordPopScale(frame: 13, wordStartFrame: 10, fps: 30),
        wordPopScale(frame: 13, wordStartFrame: 10, fps: 30),
      );
    });
  });

  group('activeWordIndex (karaoke)', () {
    final cue = CaptionCue(
      'a b c',
      start: 0.0.seconds,
      end: 3.seconds,
      words: [
        CaptionCueWord('a', at: 0.0.seconds),
        CaptionCueWord('b', at: 1.seconds),
        CaptionCueWord('c', at: 2.seconds),
      ],
    );

    test('tracks the latest word whose start has passed', () {
      expect(activeWordIndex(cue, frame: 0, scope: _scope), 0);
      expect(activeWordIndex(cue, frame: 45, scope: _scope), 1);
      expect(activeWordIndex(cue, frame: 75, scope: _scope), 2);
    });

    test('is -1 before the first word', () {
      final late = CaptionCue(
        'x',
        start: 1.seconds,
        end: 2.seconds,
        words: [CaptionCueWord('x', at: 1.seconds)],
      );
      expect(activeWordIndex(late, frame: 0, scope: _scope), -1);
    });
  });
}
