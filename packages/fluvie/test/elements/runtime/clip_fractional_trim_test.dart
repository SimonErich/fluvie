import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/rendering/clip_audio_trim.dart';

void main() {
  test('long source marks keep exact frames at fractional source fps for picture and audio', () {
    const rate = 30000 / 1001;
    const meta = (fps: rate, frameCount: 20000, width: 320, height: 180, hasAudio: true);
    final trim = const Time.seconds(10000 / rate).to(const Time.seconds(10090 / rate));
    expect(resolveClipTrimBounds(trim, meta), (start: 10000, end: 10090));
    final audio = resolveClipAudioTrimSeconds(
      trim: trim,
      meta: meta,
      windowFrames: 90,
      fps: 30,
      sourceLabel: 'fractional',
    );
    expect(audio.start, closeTo(10000 / rate, 1e-12));
    expect(audio.end, closeTo(10000 / rate + 3, 1e-12));
    expect(
      resolveClipTrimBounds(const Time.ms(333667).to(const Time.frames(10090)), meta).start,
      10000,
    );
    expect(
      resolveClipTrimBounds(
        (const Time.seconds(9990 / rate) + const Time.frames(10)).to(const Time.frames(10090)),
        meta,
      ).start,
      10000,
    );
  });
}
