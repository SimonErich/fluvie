import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/spring_solver.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/resolver/anchor_registry.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

import '../helpers/plan_builders.dart';
import '../helpers/resolve_helpers.dart';

void main() {
  // One 10s scene @30fps (frames 0..300); the element spans the whole scene.
  CompositionPlan chained(List<AnimationPlan> animations) => composition(
    scenes: [
      scene(
        'one',
        duration: 10.seconds,
        elements: [element('logo', animations: animations)],
      ),
    ],
  );

  group('Trigger.previous chains', () {
    test('previous starts where the prior animation ends', () {
      final result = resolvePlan(
        chained([
          anim(timing: const Tween(Time.frames(30))),
          anim(at: Trigger.previous, timing: const Tween(Time.frames(20))),
        ]),
      );

      expect(result.spans[0], const ResolvedSpan(0, 30));
      expect(result.spans[1], const ResolvedSpan(30, 50));
    });

    test('previous applies its delay after the prior end (D12-resolved frames)', () {
      final result = resolvePlan(
        chained([
          anim(timing: const Tween(Time.frames(30))),
          anim(
            at: Trigger.previous,
            delay: const Time.frames(10),
            timing: const Tween(Time.frames(20)),
          ),
        ]),
      );

      expect(result.spans[1], const ResolvedSpan(40, 60));
    });

    test('a three-link chain accumulates: each link starts at the previous end', () {
      final result = resolvePlan(
        chained([
          anim(timing: const Tween(Time.frames(30))),
          anim(at: Trigger.previous, timing: const Tween(Time.frames(20))),
          anim(at: Trigger.previous, timing: const Tween(Time.frames(15))),
        ]),
      );

      expect(result.spans[0], const ResolvedSpan(0, 30));
      expect(result.spans[1], const ResolvedSpan(30, 50));
      expect(result.spans[2], const ResolvedSpan(50, 65));
    });

    test('chaining after a spring starts at the spring settle frame (§27.4)', () {
      final settle = SpringSolver(Spring.snappy).settleFrames(30);
      final result = resolvePlan(
        chained([
          anim(timing: Spring.snappy),
          anim(at: Trigger.previous, timing: const Tween(Time.frames(20))),
        ]),
      );

      expect(result.spans[0], ResolvedSpan(0, settle));
      expect(result.spans[1], ResolvedSpan(settle, settle + 20));
    });

    test('previous on a first animation fails fast with a FluvieTimingError (D6)', () {
      final plan = chained([anim(at: Trigger.previous)]);

      // Through the full pipeline (the graph rejects it while adding edges)…
      expect(() => resolvePlan(plan), throwsA(isA<FluvieTimingError>()));

      // …and from the resolver itself, used standalone.
      final registry = AnchorRegistry.collect(plan);
      const scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);
      final resolver = TriggerResolver(
        plan: plan,
        registry: registry,
        resolved: <int, ResolvedSpan>{},
        windows: {plan.scenes[0].elements[0]: const ResolvedSpan(0, 300)},
      );
      expect(
        () => resolver.resolve(
          node: registry.nodes.first,
          elementScope: scope,
          window: const ResolvedSpan(0, 300),
          durationFrames: 20,
          delayFrames: 0,
        ),
        throwsA(
          isA<FluvieTimingError>().having((e) => e.message, 'message', contains('logo')),
        ),
      );
    });
  });
}
