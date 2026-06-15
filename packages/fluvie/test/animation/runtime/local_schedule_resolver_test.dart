import 'package:flutter/widgets.dart' show Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/runtime/local_schedule_resolver.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/spring_solver.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

import '../../timing/helpers/plan_builders.dart';
import '../../timing/helpers/resolve_helpers.dart';

/// A 100-frame scene at the start of a 30 fps video — the zero-offset case
/// where local resolution must equal composition resolution verbatim.
const _scene = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 100);

void main() {
  group('resolveLocalSchedule — equivalence with resolveComposition (D15)', () {
    test('a fadeIn-style enter matches the hand-built plan span for span', () {
      final schedule = resolveLocalSchedule(
        animations: [
          Animation.from(const Keyframe(opacity: 0), duration: const Time.frames(20)),
        ],
        window: null,
        sceneScope: _scene,
      );
      final reference = resolvePlan(
        composition(
          scenes: [
            scene(
              's',
              duration: const Time.frames(100),
              elements: [
                element('e', animations: [anim(timing: const Tween(Time.frames(20)))]),
              ],
            ),
          ],
        ),
      );
      expect(schedule.spans, [reference.spans[0]]);
      expect(schedule.window, reference.windows.values.single);
      expect(schedule.spans.single, const ResolvedSpan(0, 20));
    });

    test('an exit is end-anchored within the window (P3-D3)', () {
      final schedule = resolveLocalSchedule(
        animations: [
          Animation.to(const Keyframe(opacity: 0), duration: const Time.frames(20)),
        ],
        window: null,
        sceneScope: _scene,
      );
      expect(schedule.spans.single, const ResolvedSpan(80, 100));
    });

    test('a window plus a relative delay resolves against the window (P3-D5/D12)', () {
      final schedule = resolveLocalSchedule(
        animations: [
          Animation.from(
            const Keyframe(opacity: 0),
            duration: const Time.frames(10),
            delay: 0.5.relative,
          ),
        ],
        window: 30.frames.to(90.frames),
        sceneScope: _scene,
      );
      // The element scope is 60 frames long, so 0.5.relative is 30 frames:
      // the enter starts at 30 + 30 = 60.
      expect(schedule.window, const ResolvedSpan(30, 90));
      expect(schedule.spans.single, const ResolvedSpan(60, 70));
    });

    test('Trigger.previous chains spans on the same element (P3-D6)', () {
      final schedule = resolveLocalSchedule(
        animations: [
          Animation.from(const Keyframe(opacity: 0), duration: const Time.frames(20)),
          Animation.fromTo(
            Keyframe.natural,
            const Keyframe(x: 0.5),
            duration: const Time.frames(15),
            at: Trigger.previous,
          ),
        ],
        window: null,
        sceneScope: _scene,
      );
      expect(schedule.spans, const [ResolvedSpan(0, 20), ResolvedSpan(20, 35)]);
    });

    test('Trigger.previous on the first animation throws (P3-D6)', () {
      expect(
        () => resolveLocalSchedule(
          animations: [
            Animation.from(
              const Keyframe(opacity: 0),
              duration: const Time.frames(20),
              at: Trigger.previous,
            ),
          ],
          window: null,
          sceneScope: _scene,
        ),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            contains('nothing to chain after'),
          ),
        ),
      );
    });

    test('sceneStart/sceneEnd shift correctly under a non-zero scene start frame', () {
      const shifted = TimeScopeData(fps: 30, startFrame: 100, durationFrames: 60);
      final schedule = resolveLocalSchedule(
        animations: [
          Animation.from(
            const Keyframe(opacity: 0),
            duration: const Time.frames(12),
            at: Trigger.sceneStart,
          ),
          Animation.to(
            const Keyframe(opacity: 0),
            duration: const Time.frames(12),
            at: Trigger.sceneEnd,
          ),
        ],
        window: null,
        sceneScope: shifted,
      );
      expect(schedule.window, const ResolvedSpan(100, 160));
      expect(schedule.spans, const [ResolvedSpan(100, 112), ResolvedSpan(148, 160)]);
    });

    test('the whole schedule shifts by the scene start frame, window included', () {
      const shifted = TimeScopeData(fps: 30, startFrame: 100, durationFrames: 60);
      final schedule = resolveLocalSchedule(
        animations: [
          Animation.from(const Keyframe(opacity: 0), duration: const Time.frames(10)),
        ],
        window: 10.frames.to(40.frames),
        sceneScope: shifted,
      );
      expect(schedule.window, const ResolvedSpan(110, 140));
      expect(schedule.spans.single, const ResolvedSpan(110, 120));
    });

    test('Trigger.after dangles locally and throws a FluvieTimingError', () {
      expect(
        () => resolveLocalSchedule(
          animations: [
            Animation.from(const Keyframe(opacity: 0), at: Trigger.after(Anchor('other'))),
          ],
          window: null,
          sceneScope: _scene,
        ),
        throwsA(isA<FluvieTimingError>()),
      );
    });

    test('Trigger.whenStarts dangles locally and throws a FluvieTimingError', () {
      expect(
        () => resolveLocalSchedule(
          animations: [
            Animation.from(const Keyframe(opacity: 0), at: Trigger.whenStarts(Anchor('other'))),
          ],
          window: null,
          sceneScope: _scene,
        ),
        throwsA(isA<FluvieTimingError>()),
      );
    });

    test('Trigger.beat has no grid locally and throws a FluvieTimingError', () {
      expect(
        () => resolveLocalSchedule(
          animations: [
            Animation.from(const Keyframe(opacity: 0), at: const Trigger.beat()),
          ],
          window: null,
          sceneScope: _scene,
        ),
        throwsA(isA<FluvieTimingError>()),
      );
    });

    test('no animations yields a window-only schedule (anchor-timeline analogue of P3-D7)', () {
      final schedule = resolveLocalSchedule(
        animations: const [],
        window: 30.frames.to(90.frames),
        sceneScope: _scene,
      );
      expect(schedule.window, const ResolvedSpan(30, 90));
      expect(schedule.spans, isEmpty);
    });

    test('a spring span is its settle time, cross-checked against SpringSolver (P3/§27.4)', () {
      final schedule = resolveLocalSchedule(
        animations: [
          Animation.from(const Keyframe(scale: 0.8), spring: Spring.snappy),
        ],
        window: null,
        sceneScope: _scene,
      );
      final settle = SpringSolver(Spring.snappy).settleFrames(30);
      expect(schedule.spans.single, ResolvedSpan(0, settle));
    });
  });

  group('resolveLocalSchedule — defaults cascade (D14)', () {
    test('element defaults merge over the package layer', () {
      final schedule = resolveLocalSchedule(
        animations: [Animation.from(const Keyframe(opacity: 0))],
        window: null,
        sceneScope: _scene,
        elementDefaults: const Defaults(duration: Time.frames(50), ease: Ease.linear),
      );
      expect(schedule.defaults.duration, const Time.frames(50));
      expect(schedule.defaults.ease, Ease.linear);
      // The merged duration drives the resolved span.
      expect(schedule.spans.single, const ResolvedSpan(0, 50));
    });

    test('without element defaults the package cascade fills every field', () {
      final schedule = resolveLocalSchedule(
        animations: [Animation.from(const Keyframe(opacity: 0))],
        window: null,
        sceneScope: _scene,
      );
      expect(schedule.defaults.duration, Defaults.package.duration);
      expect(schedule.defaults.ease, Defaults.package.ease);
      // Package default: 20% of the 100-frame window = 20 frames.
      expect(schedule.spans.single, const ResolvedSpan(0, 20));
    });

    test('the schedule keeps phase placement per animation (enter vs exit vs during)', () {
      final schedule = resolveLocalSchedule(
        animations: [
          Animation.from(const Keyframe(opacity: 0), duration: const Time.frames(10)),
          const Animation.custom(
            _NoopEffect(),
            phase: AnimationPhase.during,
            duration: Time.frames(10),
          ),
          Animation.to(const Keyframe(opacity: 0), duration: const Time.frames(10)),
        ],
        window: null,
        sceneScope: _scene,
      );
      expect(schedule.spans, const [
        ResolvedSpan(0, 10), // enter: start-anchored
        ResolvedSpan(0, 100), // during: spans the window
        ResolvedSpan(90, 100), // exit: end-anchored
      ]);
    });
  });
}

/// A do-nothing effect for phase-placement assertions.
final class _NoopEffect implements AnimationEffect {
  const _NoopEffect();

  @override
  Widget build(Widget child, double progress) => child;
}
