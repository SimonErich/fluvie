// Task 22: planClipFrames walks a clip's composition window through the
// floor-resampling rule and returns the distinct source frames it will read,
// sorted. That minimal set is exactly what the clip pre-pass extracts, so a
// slow source under a fast composition extracts each held frame once.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie_media/fluvie_media.dart';

void main() {
  test('variable-rate clips follow display timestamps for trims, rates and reverse', () {
    final timeline = MediaTimeline.fromTimestamps([0, 100000, 600000], endTimeUs: 1000000);
    expect(
      planClipFrames(
        windowStart: 0,
        windowLength: 5,
        compFps: 10,
        srcFps: 3,
        trimStartFrames: 0,
        trimEndFrames: 3,
        timeline: timeline,
      ),
      [0, 1],
    );
    expect(
      planClipFrames(
        windowStart: 0,
        windowLength: 5,
        compFps: 10,
        srcFps: 3,
        trimStartFrames: 0,
        trimEndFrames: 3,
        speed: 2,
        timeline: timeline,
      ),
      [0, 1, 2],
    );
    expect(
      planClipFrames(
        windowStart: 0,
        windowLength: 6,
        compFps: 10,
        srcFps: 3,
        trimStartFrames: 0,
        trimEndFrames: 3,
        speed: -1,
        timeline: timeline,
      ),
      [1, 2],
    );
    const meta = (fps: 3.0, frameCount: 3, width: 2, height: 2, hasAudio: true);
    final offsets = resolveClipTrimOffsets(
      const Time.seconds(0.2).to(const Time.seconds(0.6)),
      meta,
      timeline: timeline,
    );
    expect(offsets.start, closeTo(1.2, 1e-9));
    expect(offsets.end, 2);
  });

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
