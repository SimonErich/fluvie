import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:fluvie/src/timing/plan/scene_plan.dart';

import 'fakes/fake_beat_grid.dart';
import 'helpers/plan_builders.dart' as dsl;

void main() {
  group('AnimationPlan', () {
    test('defaults: no timing, zero delay, auto trigger, no label', () {
      const plan = AnimationPlan(phase: AnimationPhase.enter);
      expect(plan.phase, AnimationPhase.enter);
      expect(plan.timing, isNull);
      expect(plan.delay, Time.zero);
      expect(plan.at, Trigger.auto);
      expect(plan.label, isNull);
    });

    test('carries explicit timing, delay, trigger, and label', () {
      const plan = AnimationPlan(
        phase: AnimationPhase.exit,
        timing: Tween(Time.seconds(0.5), ease: Ease.out),
        delay: Time.seconds(0.2),
        at: Trigger.sceneEnd,
        label: 'farewell',
      );
      expect(plan.phase, AnimationPhase.exit);
      expect(plan.timing, const Tween(Time.seconds(0.5), ease: Ease.out));
      expect(plan.delay, const SecondTime(0.2));
      expect(plan.at, Trigger.sceneEnd);
      expect(plan.label, 'farewell');
    });

    test('stagger and repeat default to null (D12/D13)', () {
      const plan = AnimationPlan(phase: AnimationPhase.enter);
      expect(plan.stagger, isNull);
      expect(plan.repeat, isNull);
    });

    test('stagger and repeat are carried verbatim as pass-through data', () {
      const plan = AnimationPlan(
        phase: AnimationPhase.during,
        stagger: Stagger.each(Time.ms(80)),
        repeat: Repeat.forever(yoyo: true),
      );
      expect(plan.stagger, const Stagger.each(Time.ms(80)));
      expect(plan.repeat, const Repeat.forever(yoyo: true));
    });
  });

  group('ElementPlan', () {
    test('defaults: no anchor, no window, no animations, no defaults', () {
      const plan = ElementPlan(ownerId: 'title');
      expect(plan.ownerId, 'title');
      expect(plan.anchor, isNull);
      expect(plan.window, isNull);
      expect(plan.animations, isEmpty);
      expect(plan.defaults, isNull);
    });

    test('carries anchor, window, animations, and defaults', () {
      final intro = Anchor('intro');
      final plan = ElementPlan(
        ownerId: 'subtitle',
        anchor: intro,
        window: 1.seconds.to(3.seconds),
        animations: const [AnimationPlan(phase: AnimationPhase.enter)],
        defaults: const Defaults(ease: Ease.snappy),
      );
      expect(plan.anchor, same(intro));
      expect(plan.window, isA<TimeRange>());
      expect(plan.animations, hasLength(1));
      expect(plan.defaults?.ease, Ease.snappy);
    });
  });

  group('ScenePlan and CompositionPlan', () {
    test('ScenePlan carries id, duration, elements, defaults', () {
      const plan = ScenePlan(
        id: 'intro-scene',
        duration: Time.seconds(3),
        elements: [ElementPlan(ownerId: 'title')],
        defaults: Defaults(duration: Time.seconds(0.4)),
      );
      expect(plan.id, 'intro-scene');
      expect(plan.duration, const SecondTime(3));
      expect(plan.elements.single.ownerId, 'title');
      expect(plan.defaults?.duration, const SecondTime(0.4));
    });

    test('CompositionPlan defaults: no defaults, no beat grids', () {
      const plan = CompositionPlan(fps: 30, scenes: []);
      expect(plan.fps, 30);
      expect(plan.scenes, isEmpty);
      expect(plan.defaults, isNull);
      expect(plan.defaultBeatGrid, isNull);
      expect(plan.trackBeatGrids, isEmpty);
    });

    test('CompositionPlan carries beat grids keyed by anchor identity', () {
      final track = Anchor('music');
      final grid = FakeBeatGrid(const [0, 15, 30]);
      final plan = CompositionPlan(
        fps: 24,
        scenes: const [],
        defaultBeatGrid: grid,
        trackBeatGrids: {track: grid},
      );
      expect(plan.fps, 24);
      expect(plan.defaultBeatGrid, same(grid));
      expect(plan.trackBeatGrids[track], same(grid));
    });
  });

  group('plan builders DSL', () {
    test('anim() produces the documented defaults', () {
      final plan = dsl.anim();
      expect(plan.phase, AnimationPhase.enter);
      expect(plan.timing, isNull);
      expect(plan.delay, Time.zero);
      expect(plan.at, Trigger.auto);
      expect(plan.label, isNull);
    });

    test('element() and scene() compose into a composition()', () {
      final logo = Anchor('logo');
      final plan = dsl.composition(
        scenes: [
          dsl.scene(
            's1',
            duration: 3.seconds,
            elements: [
              dsl.element(
                'logo',
                anchor: logo,
                animations: [dsl.anim(timing: Spring.bouncy)],
              ),
              dsl.element('caption', window: 1.seconds.to(2.seconds)),
            ],
          ),
          dsl.scene('s2', duration: 4.seconds),
        ],
      );
      expect(plan.fps, 30);
      expect(plan.scenes, hasLength(2));
      expect(plan.scenes.first.elements.first.anchor, same(logo));
      expect(plan.scenes.first.elements.first.animations.single.timing, Spring.bouncy);
      expect(plan.scenes.first.elements.last.window, isNotNull);
      expect(plan.scenes.last.elements, isEmpty);
    });
  });
}
