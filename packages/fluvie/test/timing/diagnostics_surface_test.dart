import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/stagger_origin.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/resolver/anchor_registry.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

import 'helpers/plan_builders.dart';

// Builds at run time so const canonicalization cannot pre-evaluate the
// constructor (run-time construction is what coverage measures).
T runtime<T>(T Function() build) => build();

void main() {
  group('diagnostics surface (toString/hashCode) stays stable', () {
    test('marker trigger hashCodes agree with their equality', () {
      expect(runtime(SceneStartTrigger.new).hashCode, Trigger.sceneStart.hashCode);
      expect(runtime(SceneEndTrigger.new).hashCode, Trigger.sceneEnd.hashCode);
      expect(runtime(PreviousTrigger.new).hashCode, Trigger.previous.hashCode);
    });

    test('whenStarts hashes by anchor identity', () {
      final a = Anchor('a');
      expect(Trigger.whenStarts(a).hashCode, Trigger.whenStarts(a).hashCode);
      expect(Trigger.whenStarts(a).hashCode, isNot(Trigger.whenStarts(Anchor('a')).hashCode));
    });

    test('mixed-unit difference hashes equal for equal operands', () {
      expect((1.seconds - 5.frames).hashCode, (1.seconds - 5.frames).hashCode);
    });

    test('ResolvedSpan is value-hashable and prints its range', () {
      expect(const ResolvedSpan(3, 9).hashCode, const ResolvedSpan(3, 9).hashCode);
      expect(const ResolvedSpan(3, 9).toString(), 'ResolvedSpan(3..9)');
    });

    test('TimeRange prints both endpoints', () {
      expect(1.seconds.to(2.seconds).toString(), contains('to'));
    });

    test('plan types print their identifying fields', () {
      final plan = composition(
        scenes: [
          scene(
            's1',
            duration: 2.seconds,
            elements: [
              element('title', animations: [anim()]),
            ],
          ),
        ],
      );
      expect(plan.toString(), contains('fps: 30'));
      expect(plan.scenes.single.toString(), contains('s1'));
      expect(plan.scenes.single.elements.single.toString(), contains('title'));
      expect(plan.scenes.single.elements.single.animations.single.toString(), contains('delay'));
    });

    test('AnimationNode prints its position', () {
      final plan = composition(
        scenes: [
          scene(
            's1',
            duration: 2.seconds,
            elements: [
              element('title', animations: [anim()]),
            ],
          ),
        ],
      );
      final node = AnchorRegistry.collect(plan).nodes.single;
      expect(node.toString(), contains('title'));
      expect(node.toString(), contains('#0'));
    });
  });

  group('stagger variants construct at run time', () {
    test('each/evenly/from carry their payloads', () {
      expect(runtime(() => Stagger.each(2.frames)), Stagger.each(2.frames));
      expect(runtime(() => Stagger.evenly(over: 1.seconds)), Stagger.evenly(over: 1.seconds));
      expect(
        runtime(() => Stagger.from(StaggerOrigin.center, gap: 2.frames)),
        Stagger.from(StaggerOrigin.center, gap: 2.frames),
      );
    });
  });

  group('TriggerResolver misuse is a StateError (programmer error)', () {
    const scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60);

    test('anchorTimeline without a window entry for the element throws', () {
      final a = Anchor('a');
      final plan = composition(
        scenes: [
          scene(
            's1',
            duration: 2.seconds,
            elements: [element('e1', anchor: a)],
          ),
        ],
      );
      final registry = AnchorRegistry.collect(plan);
      final resolver = TriggerResolver(
        plan: plan,
        registry: registry,
        resolved: const {},
        windows: const {},
      );
      expect(() => resolver.anchorTimeline(a), throwsStateError);
    });

    test('resolving against an unresolved previous node throws', () {
      final plan = composition(
        scenes: [
          scene(
            's1',
            duration: 2.seconds,
            elements: [
              element(
                'e1',
                animations: [
                  anim(),
                  anim(at: Trigger.previous),
                ],
              ),
            ],
          ),
        ],
      );
      final registry = AnchorRegistry.collect(plan);
      final resolver = TriggerResolver(
        plan: plan,
        registry: registry,
        resolved: const {},
        windows: const {},
      );
      expect(
        () => resolver.resolve(
          node: registry.nodes[1],
          elementScope: scope,
          window: const ResolvedSpan(0, 60),
          durationFrames: 10,
          delayFrames: 0,
        ),
        throwsStateError,
      );
    });

    test('a windowed element whose scope has no parent throws', () {
      final plan = composition(
        scenes: [
          scene(
            's1',
            duration: 2.seconds,
            elements: [
              element(
                'e1',
                window: 0.5.seconds.to(1.5.seconds),
                animations: [anim(at: Trigger.sceneStart)],
              ),
            ],
          ),
        ],
      );
      final registry = AnchorRegistry.collect(plan);
      final resolver = TriggerResolver(
        plan: plan,
        registry: registry,
        resolved: const {},
        windows: const {},
      );
      // A parentless scope cannot be the child scope of a windowed element.
      expect(
        () => resolver.resolve(
          node: registry.nodes.single,
          elementScope: scope,
          window: const ResolvedSpan(15, 45),
          durationFrames: 10,
          delayFrames: 0,
        ),
        throwsStateError,
      );
    });
  });
}
