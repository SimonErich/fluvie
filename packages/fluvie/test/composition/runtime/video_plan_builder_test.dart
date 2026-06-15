import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/video_plan_builder.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_registration.dart';
import 'package:fluvie/src/timing/timeline/debug_timeline.dart';

import '../../timing/fakes/fake_beat_grid.dart';

/// An enter animation lasting [frames], linear, with an optional trigger.
AnimationPlan _enter(int frames, {Trigger at = Trigger.auto, Time delay = Time.zero}) =>
    AnimationPlan(
      phase: AnimationPhase.enter,
      timing: Tween(Time.frames(frames), ease: Ease.linear),
      at: at,
      delay: delay,
    );

({Time duration, Defaults? defaults}) _scene(Time duration, {Defaults? defaults}) =>
    (duration: duration, defaults: defaults);

void main() {
  group('buildVideoPlan (WI-14)', () {
    test('two-scene plan: scene 2 spans are offset by scene 1 frames', () {
      final token = ElementRegistration(debugOwner: 'Box', animations: [_enter(10)]);
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames), _scene(30.frames)],
        registrationsByScene: [
          const <ElementRegistration>[],
          [token],
        ],
      );
      expect(result.schedules[token]!.window, const ResolvedSpan(60, 90));
      expect(result.schedules[token]!.spans, [const ResolvedSpan(60, 70)]);
      expect(result.timeline.totalFrames, 90);
    });

    test('cross-scene Trigger.after chains off the anchor union end', () {
      final bg = Anchor('bg');
      final anchored = ElementRegistration(
        debugOwner: 'bg',
        anchor: bg,
        animations: [_enter(60)],
      );
      final follower = ElementRegistration(
        debugOwner: 'Text',
        animations: [_enter(10, at: Trigger.after(bg))],
      );
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames), _scene(30.frames)],
        registrationsByScene: [
          [anchored],
          [follower],
        ],
      );
      expect(result.schedules[anchored]!.spans, [const ResolvedSpan(0, 60)]);
      expect(result.schedules[follower]!.spans, [const ResolvedSpan(60, 70)]);
      expect(result.timeline.warnings, isEmpty);
    });

    test('Trigger.whenStarts chains off the anchor union start', () {
      final bg = Anchor('bg');
      final anchored = ElementRegistration(
        debugOwner: 'bg',
        anchor: bg,
        animations: [_enter(20, delay: 10.frames)],
      );
      final follower = ElementRegistration(
        debugOwner: 'Text',
        animations: [_enter(5, at: Trigger.whenStarts(bg))],
      );
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames)],
        registrationsByScene: [
          [anchored, follower],
        ],
      );
      expect(result.schedules[anchored]!.spans, [const ResolvedSpan(10, 30)]);
      expect(result.schedules[follower]!.spans, [const ResolvedSpan(10, 15)]);
    });

    test('Trigger.beat resolves under the default FakeBeatGrid (D20)', () {
      final token = ElementRegistration(
        debugOwner: 'Box',
        animations: [_enter(10, at: const Trigger.beat())],
      );
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames)],
        registrationsByScene: [
          [token],
        ],
        defaultBeatGrid: FakeBeatGrid([12]),
      );
      expect(result.schedules[token]!.spans, [const ResolvedSpan(12, 22)]);
    });

    test('Trigger.beat(track:) resolves against the track grid (D20)', () {
      final drums = Anchor('drums');
      final token = ElementRegistration(
        debugOwner: 'Box',
        animations: [_enter(10, at: Trigger.beat(track: drums))],
      );
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames)],
        registrationsByScene: [
          [token],
        ],
        defaultBeatGrid: FakeBeatGrid([20]),
        trackBeatGrids: {
          drums: FakeBeatGrid([8]),
        },
      );
      expect(result.schedules[token]!.spans, [const ResolvedSpan(8, 18)]);
    });

    test('the no-grid beat error names the element and suggests a fix (D20)', () {
      final token = ElementRegistration(
        debugOwner: 'Box',
        animations: [_enter(10, at: const Trigger.beat())],
      );
      expect(
        () => buildVideoPlan(
          fps: 30,
          scenes: [_scene(60.frames)],
          registrationsByScene: [
            [token],
          ],
        ),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            allOf(contains('Trigger.beat'), contains('Box'), contains('beat-tagged Audio')),
          ),
        ),
      );
    });

    test('the cascade merges element > scene > video > package per field (D17)', () {
      // No element timing: the duration must come from the video layer while
      // the ease comes from the scene layer — per-field cascading.
      final token = ElementRegistration(
        debugOwner: 'Box',
        animations: const [AnimationPlan(phase: AnimationPhase.enter)],
      );
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames, defaults: const Defaults(ease: Ease.linear))],
        registrationsByScene: [
          [token],
        ],
        videoDefaults: const Defaults(duration: Time.frames(10)),
      );
      final schedule = result.schedules[token]!;
      expect(schedule.defaults.duration, const Time.frames(10));
      expect(schedule.defaults.ease, Ease.linear);
      expect(schedule.spans, [const ResolvedSpan(0, 10)]);
    });

    test('element defaults win over scene and video layers (D17)', () {
      final token = ElementRegistration(
        debugOwner: 'Box',
        animations: const [AnimationPlan(phase: AnimationPhase.enter)],
        defaults: const Defaults(duration: Time.frames(7)),
      );
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames, defaults: const Defaults(duration: Time.frames(20)))],
        registrationsByScene: [
          [token],
        ],
        videoDefaults: const Defaults(duration: Time.frames(40)),
      );
      expect(result.schedules[token]!.spans, [const ResolvedSpan(0, 7)]);
    });

    test('a window-only registration (no animations) gets a window-only schedule', () {
      final token = ElementRegistration(
        debugOwner: 'Box',
        window: 30.frames.to(50.frames),
      );
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames)],
        registrationsByScene: [
          [token],
        ],
      );
      final schedule = result.schedules[token]!;
      expect(schedule.window, const ResolvedSpan(30, 50));
      expect(schedule.spans, isEmpty);
    });

    test('a windowed registration in a later scene resolves scene-relative (D22)', () {
      final token = ElementRegistration(
        debugOwner: 'Box',
        window: 10.frames.to(20.frames),
        animations: [_enter(5)],
      );
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames), _scene(30.frames)],
        registrationsByScene: [
          const <ElementRegistration>[],
          [token],
        ],
      );
      expect(result.schedules[token]!.window, const ResolvedSpan(70, 80));
      expect(result.schedules[token]!.spans, [const ResolvedSpan(70, 75)]);
    });

    test('field-identical tokens in two scenes resolve to distinct windows (D18)', () {
      final first = ElementRegistration(debugOwner: 'Box');
      final second = ElementRegistration(debugOwner: 'Box');
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames), _scene(30.frames)],
        registrationsByScene: [
          [first],
          [second],
        ],
      );
      expect(result.schedules, hasLength(2));
      expect(result.schedules[first]!.window, const ResolvedSpan(0, 60));
      expect(result.schedules[second]!.window, const ResolvedSpan(60, 90));
      // One fresh ElementPlan per token — never a shared instance (D18).
      expect(
        identical(result.plan.scenes[0].elements.single, result.plan.scenes[1].elements.single),
        isFalse,
      );
    });

    test('a token registered in two scenes is rejected (D18 guard)', () {
      final token = ElementRegistration(debugOwner: 'Box');
      expect(
        () => buildVideoPlan(
          fps: 30,
          scenes: [_scene(60.frames), _scene(30.frames)],
          registrationsByScene: [
            [token],
            [token],
          ],
        ),
        throwsArgumentError,
      );
    });

    test('ownerIds follow s<scene>e<order>:<debugOwner> (D19)', () {
      final bg = Anchor('bg');
      final box = ElementRegistration(debugOwner: 'Box', animations: [_enter(5)]);
      final anchored = ElementRegistration(debugOwner: 'bg', anchor: bg, animations: [_enter(5)]);
      final text = ElementRegistration(debugOwner: 'Text', animations: [_enter(5)]);
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames), _scene(30.frames)],
        registrationsByScene: [
          [box, anchored],
          [text],
        ],
      );
      expect(result.plan.scenes[0].elements[0].ownerId, 's0e0:Box');
      expect(result.plan.scenes[0].elements[1].ownerId, 's0e1:bg');
      expect(result.plan.scenes[1].elements[0].ownerId, 's1e0:Text');
      expect(result.timeline.rows.map((row) => row.ownerId), contains('s0e1:bg'));
    });

    test('schedules are keyed by token identity', () {
      final registered = ElementRegistration(debugOwner: 'Box');
      final lookalike = ElementRegistration(debugOwner: 'Box');
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames)],
        registrationsByScene: [
          [registered],
        ],
      );
      expect(result.schedules.containsKey(registered), isTrue);
      expect(result.schedules.containsKey(lookalike), isFalse);
    });

    test('spans align with the animations index by index', () {
      final token = ElementRegistration(
        debugOwner: 'Box',
        animations: [
          _enter(10),
          const AnimationPlan(
            phase: AnimationPhase.exit,
            timing: Tween(Time.frames(10), ease: Ease.linear),
            at: Trigger.previous,
          ),
        ],
      );
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames)],
        registrationsByScene: [
          [token],
        ],
      );
      expect(result.schedules[token]!.spans, [
        const ResolvedSpan(0, 10),
        const ResolvedSpan(10, 20),
      ]);
    });

    test('scene and video defaults land on the plan (D17)', () {
      const sceneDefaults = Defaults(ease: Ease.linear);
      const videoDefaults = Defaults(duration: Time.frames(10));
      final result = buildVideoPlan(
        fps: 30,
        scenes: [_scene(60.frames, defaults: sceneDefaults)],
        registrationsByScene: const [<ElementRegistration>[]],
        videoDefaults: videoDefaults,
      );
      expect(result.plan.defaults, same(videoDefaults));
      expect(result.plan.scenes.single.defaults, same(sceneDefaults));
    });

    test('mismatched scenes and registration lists are rejected', () {
      expect(
        () => buildVideoPlan(fps: 30, scenes: [_scene(60.frames)], registrationsByScene: const []),
        throwsArgumentError,
      );
    });

    test('two builds of the same input produce identical output (determinism)', () {
      final bg = Anchor('bg');
      final anchored = ElementRegistration(debugOwner: 'bg', anchor: bg, animations: [_enter(30)]);
      final follower = ElementRegistration(
        debugOwner: 'Text',
        animations: [_enter(10, at: Trigger.after(bg))],
      );
      final scenes = [_scene(60.frames)];
      final registrations = [
        [anchored, follower],
      ];
      final first = buildVideoPlan(fps: 30, scenes: scenes, registrationsByScene: registrations);
      final second = buildVideoPlan(fps: 30, scenes: scenes, registrationsByScene: registrations);
      expect(debugTimeline(first.timeline), debugTimeline(second.timeline));
      expect(first.schedules[anchored], second.schedules[anchored]);
      expect(first.schedules[follower], second.schedules[follower]);
    });
  });
}
