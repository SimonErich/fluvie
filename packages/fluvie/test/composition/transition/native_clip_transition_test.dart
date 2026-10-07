import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

import '../../serialization/element_transition_spec_test.dart' show deck;

ClipTransitionGroup _group({
  Transition transition = const Transition.crossFade(Time.frames(10)),
  String? incomingLane = 'v1',
}) => ClipTransitionGroup(
  transitions: [ClipTransition(outgoing: 'a', incoming: 'b', transition: transition)],
  children: [
    ElementId(
      id: 'a',
      lane: 'v1',
      child: Clip.asset('a.mp4').show(from: 0.frames, to: 60.frames),
    ),
    ElementId(
      id: 'b',
      lane: incomingLane,
      child: Clip.asset('b.mp4').show(from: 60.frames, to: 120.frames),
    ),
  ],
);

void main() {
  test(
    'native and JSON clip transitions share picture windows and every audio envelope sample',
    () {
      for (final overlap in [true, false]) {
        final native = Video(
          scenes: [
            Scene(
              duration: 120.frames,
              children: [_group(transition: Transition.crossFade(10.frames, overlap: overlap))],
            ),
          ],
        );
        final serialized = VideoSpec.fromJson(
          deck(
            transition: {
              'between': ['a', 'b'],
              'kind': 'crossFade',
              'duration': '10f',
              'overlap': overlap,
            },
          ),
        ).build();
        final nativePictures = collectClipPlans(native.scenes, 30, sceneStartFrames: [0]);
        final specPictures = collectClipPlans(serialized.scenes, 30, sceneStartFrames: [0]);
        expect(nativePictures, specPictures);
        final nativeAudio = collectClipAudioPlans(native.scenes, 30, sceneStartFrames: [0]);
        final specAudio = collectClipAudioPlans(serialized.scenes, 30, sceneStartFrames: [0]);
        for (var i = 0; i < nativeAudio.length; i++) {
          final a = nativeAudio[i];
          final b = specAudio[i];
          expect(a.startFrame, b.startFrame);
          expect(a.windowFrames, b.windowFrames);
          final ae = a.audio.automation.resolve(fps: 30, windowFrames: a.windowFrames);
          final be = b.audio.automation.resolve(fps: 30, windowFrames: b.windowFrames);
          for (var frame = 0; frame <= a.windowFrames; frame++) {
            expect(audioVolumeAt(ae, frame / 30), audioVolumeAt(be, frame / 30));
          }
        }
      }
    },
  );

  test('native lane validation reports a timing error with the same rule as JSON', () {
    expect(
      () => _group(
        incomingLane: 'other',
      ).resolve(const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 120)),
      throwsA(
        isA<FluvieTimingError>().having((error) => error.message, 'message', contains('same lane')),
      ),
    );
  });

  test(
    'ElementId retains SpecElementId compatibility and gain scaling retains automation/fades/mute',
    () {
      expect(const ElementId(id: 'a', child: SizedBox()), isA<SpecElementId>());
      final original = ClipAudio.included(
        volume: 0.8,
        automation: const AudioAutomation(values: [0.5]),
        fadeIn: 2.frames,
        fadeOut: 3.frames,
      );
      final scaled = original.scaledBy(0.5);
      expect(scaled.volume, 0.4);
      expect(scaled.automation, same(original.automation));
      expect(scaled.fadeIn, original.fadeIn);
      expect(scaled.fadeOut, original.fadeOut);
      expect(const ClipAudio.muted().scaledBy(2).muted, isTrue);
      for (final gain in [-1.0, double.nan, double.infinity]) {
        expect(() => original.scaledBy(gain), throwsArgumentError);
      }
    },
  );
}
