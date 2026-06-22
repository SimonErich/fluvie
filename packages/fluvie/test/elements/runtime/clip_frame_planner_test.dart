// Task 22: planClipFrames walks a clip's composition window through the
// floor-resampling rule and returns the distinct source frames it will read,
// sorted. That minimal set is exactly what the clip pre-pass extracts, so a
// slow source under a fast composition extracts each held frame once.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';

void main() {
  test('1:1 fps with no trim needs one source frame per composition frame', () {
    final frames = planClipFrames(
      windowStart: 0,
      windowLength: 4,
      compFps: 30,
      srcFps: 30,
      trimStartFrames: 0,
      trimEndFrames: 30,
    );

    expect(frames, [0, 1, 2, 3]);
  });

  test('a half-speed source repeats frames, so each is extracted once', () {
    final frames = planClipFrames(
      windowStart: 0,
      windowLength: 4,
      compFps: 30,
      srcFps: 15,
      trimStartFrames: 0,
      trimEndFrames: 30,
    );

    expect(frames, [0, 1], reason: 'frames 0 and 1 each cover two composition frames');
  });

  test('a trim offset shifts the planned frames to the trim start', () {
    final frames = planClipFrames(
      windowStart: 5,
      windowLength: 3,
      compFps: 30,
      srcFps: 30,
      trimStartFrames: 10,
      trimEndFrames: 20,
    );

    expect(frames, [10, 11, 12]);
  });

  test('a window outliving the trimmed source holds the last frame', () {
    final frames = planClipFrames(
      windowStart: 0,
      windowLength: 6,
      compFps: 30,
      srcFps: 30,
      trimStartFrames: 0,
      trimEndFrames: 3,
    );

    expect(frames, [0, 1, 2], reason: 'frames past trimEnd clamp to the last source frame');
  });

  test('an empty window plans no frames', () {
    expect(
      planClipFrames(
        windowStart: 0,
        windowLength: 0,
        compFps: 30,
        srcFps: 30,
        trimStartFrames: 0,
        trimEndFrames: 30,
      ),
      isEmpty,
    );
  });

  test('the result is sorted and distinct', () {
    final frames = planClipFrames(
      windowStart: 0,
      windowLength: 20,
      compFps: 30,
      srcFps: 12,
      trimStartFrames: 0,
      trimEndFrames: 30,
    );

    final sortedDistinct = frames.toSet().toList()..sort();
    expect(frames, sortedDistinct);
  });
}
