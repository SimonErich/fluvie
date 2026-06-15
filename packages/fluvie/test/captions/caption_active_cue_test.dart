// WI-19 (D-CaptionsRender, §17): the active-cue selection. A cue is active over
// [start, end); outside every window the result is null; overlaps take the last
// match (caption-on-top reading order). Pure and deterministic.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/runtime/caption_active_cue.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);

List<CaptionCue> _cues() => [
  CaptionCue('first', start: 0.0.seconds, end: 1.seconds),
  CaptionCue('second', start: 1.seconds, end: 2.seconds),
];

void main() {
  group('activeCue', () {
    test('returns the cue whose window contains the frame', () {
      expect(activeCue(_cues(), frame: 15, scope: _scope)?.text, 'first');
      expect(activeCue(_cues(), frame: 45, scope: _scope)?.text, 'second');
    });

    test('is null before the first cue and after the last', () {
      final later = [CaptionCue('x', start: 1.seconds, end: 2.seconds)];
      expect(activeCue(later, frame: 0, scope: _scope), isNull);
      expect(activeCue(_cues(), frame: 1000, scope: _scope), isNull);
    });

    test('the window is half-open: the end frame belongs to the next cue', () {
      // 1.0s == frame 30: the first cue ends, the second begins.
      expect(activeCue(_cues(), frame: 30, scope: _scope)?.text, 'second');
    });

    test('an empty cue list is always null', () {
      expect(activeCue(const [], frame: 0, scope: _scope), isNull);
    });

    test('overlapping windows take the last matching cue', () {
      final overlap = [
        CaptionCue('a', start: 0.0.seconds, end: 2.seconds),
        CaptionCue('b', start: 1.seconds, end: 3.seconds),
      ];
      expect(activeCue(overlap, frame: 45, scope: _scope)?.text, 'b');
    });
  });
}
