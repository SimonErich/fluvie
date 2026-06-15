// Epic 14.5 (WI-23, D-SfxWiring): resolveSfxFrame turns an sfx `at:` Trigger
// into an absolute composition frame at composition scope, so stageAudioMix can
// convert it to an AudioTrackNode delay.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/encoding/sfx_trigger_resolver.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

void main() {
  const scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);

  group('resolveSfxFrame', () {
    test('a null trigger fires at the composition start (frame 0)', () {
      expect(resolveSfxFrame(null, scope), 0);
    });

    test('Trigger.at(seconds) resolves against the composition fps', () {
      expect(resolveSfxFrame(Trigger.at(1.seconds), scope), 30);
      expect(resolveSfxFrame(Trigger.at(2.seconds), scope), 60);
    });

    test('Trigger.at(frames) resolves to the same frame', () {
      expect(resolveSfxFrame(const Trigger.at(Time.frames(15)), scope), 15);
    });

    test('Trigger.at(zero) fires at frame 0', () {
      expect(resolveSfxFrame(const Trigger.at(Time.zero), scope), 0);
    });

    test('a relative absolute time resolves against the composition duration', () {
      // 0.5 of a 300-frame composition window = frame 150.
      expect(resolveSfxFrame(Trigger.at(0.5.relative), scope), 150);
    });

    test('a scene/anchor trigger throws an honest error (no composition context)', () {
      expect(
        () => resolveSfxFrame(Trigger.sceneStart, scope),
        throwsA(isA<FluvieTimingError>()),
      );
      expect(
        () => resolveSfxFrame(Trigger.after(Anchor('x')), scope),
        throwsA(isA<FluvieTimingError>()),
      );
      expect(
        () => resolveSfxFrame(const Trigger.beat(), scope),
        throwsA(isA<FluvieTimingError>()),
      );
    });
  });
}
