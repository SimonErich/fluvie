import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart' show MediaTimeline;
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/rendering/clip_audio_trim.dart';

void main() {
  test('VFR frame trims open embedded sound on the picture presentation timestamp', () {
    final timeline = MediaTimeline.fromTimestamps([0, 100000, 600000], endTimeUs: 1000000);
    final trim = resolveClipAudioTrimSeconds(
      trim: 1.frames.to(2.frames),
      meta: (fps: 3, frameCount: 3, width: 32, height: 32, hasAudio: true),
      windowFrames: 10,
      fps: 10,
      sourceLabel: 'cat.mp4',
      timeline: timeline,
    );
    expect(trim.start, 0.1);
    expect(trim.end, 0.6);
  });

  test('audio trim retains subframe source phase at fractional source fps', () {
    const metadata = (
      fps: 30000 / 1001,
      frameCount: 300,
      width: 16,
      height: 9,
      hasAudio: true,
    );
    final trim = resolveClipAudioTrimSeconds(
      trim: 0.12345.seconds.to(2.98765.seconds),
      meta: metadata,
      windowFrames: 30,
      fps: 30,
      sourceLabel: 'fractional.mp4',
    );
    expect(trim.start, closeTo(0.12345, 1e-12));
    expect(trim.end, closeTo(1.12345, 1e-12));
    final capped = resolveClipAudioTrimSeconds(
      trim: 0.12345.seconds.to(2.98765.seconds),
      meta: metadata,
      windowFrames: 90,
      fps: 30,
      sourceLabel: 'fractional.mp4',
    );
    expect(capped.end, closeTo(2.98765, 1e-12));
  });
}
