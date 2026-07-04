import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';

import '../helpers/plan_builders.dart';
import '../helpers/resolve_helpers.dart';

void main() {
  // All single-scene cases live in a 10s scene @30fps: frames 0..300.
  CompositionPlan single(List<ElementPlan> elements) => composition(
    scenes: [scene('one', duration: 10.seconds, elements: elements)],
  );

  group('cross-element triggers', () {
    test("after(anchor) starts at the anchored timeline's union end (D7)", () {
      final hero = Anchor('hero');
      final result = resolvePlan(
        single([
          element(
            'title',
            anchor: hero,
            animations: [anim(timing: const Tween(Time.frames(30)))],
          ),
          element(
            'subtitle',
            animations: [
              anim(at: Trigger.whenEnds(hero), timing: const Tween(Time.frames(20))),
            ],
          ),
        ]),
      );

      expect(result.spans[0], const ResolvedSpan(0, 30));
      expect(result.spans[1], const ResolvedSpan(30, 50));
    });

    test('after applies its delay after the anchored end', () {
      final hero = Anchor('hero');
      final result = resolvePlan(
        single([
          element(
            'title',
            anchor: hero,
            animations: [anim(timing: const Tween(Time.frames(30)))],
          ),
          element(
            'subtitle',
            animations: [
              anim(
                at: Trigger.whenEnds(hero),
                delay: 0.5.seconds,
                timing: const Tween(Time.frames(20)),
              ),
            ],
          ),
        ]),
      );

      expect(result.spans[1], const ResolvedSpan(45, 65));
    });

    test('whenStarts(anchor) starts with the anchored timeline', () {
      final hero = Anchor('hero');
      final result = resolvePlan(
        single([
          element(
            'title',
            anchor: hero,
            window: 2.seconds.to(8.seconds),
            animations: [anim(timing: const Tween(Time.frames(30)))],
          ),
          element(
            'subtitle',
            animations: [
              anim(at: Trigger.whenStarts(hero), timing: const Tween(Time.frames(20))),
            ],
          ),
        ]),
      );

      expect(result.spans[0], const ResolvedSpan(60, 90));
      expect(result.spans[1], const ResolvedSpan(60, 80));
    });

    test('whenStarts applies its delay after the anchored start', () {
      final hero = Anchor('hero');
      final result = resolvePlan(
        single([
          element(
            'title',
            anchor: hero,
            window: 2.seconds.to(8.seconds),
            animations: [anim(timing: const Tween(Time.frames(30)))],
          ),
          element(
            'subtitle',
            animations: [
              anim(
                at: Trigger.whenStarts(hero),
                delay: const Time.frames(10),
                timing: const Tween(Time.frames(20)),
              ),
            ],
          ),
        ]),
      );

      expect(result.spans[1], const ResolvedSpan(70, 90));
    });

    test('anchorTimeline unions every resolved animation on the element (D7)', () {
      final hero = Anchor('hero');
      final result = resolvePlan(
        single([
          element(
            'title',
            anchor: hero,
            animations: [
              anim(timing: const Tween(Time.frames(30))),
              anim(phase: AnimationPhase.exit, timing: const Tween(Time.frames(30))),
            ],
          ),
          element(
            'cta',
            animations: [
              anim(at: Trigger.whenEnds(hero), timing: const Tween(Time.frames(20))),
            ],
          ),
        ]),
      );

      // Enter [0, 30], auto exit end-anchored [270, 300] → union [0, 300].
      expect(result.resolver.anchorTimeline(hero), const ResolvedSpan(0, 300));
      expect(result.spans[2], const ResolvedSpan(300, 320));
    });

    test('anchorTimeline of an animation-less element is its window (D7)', () {
      final hero = Anchor('hero');
      final result = resolvePlan(
        single([
          element('backdrop', anchor: hero, window: 1.seconds.to(3.seconds)),
          element(
            'cta',
            animations: [
              anim(at: Trigger.whenEnds(hero), timing: const Tween(Time.frames(20))),
            ],
          ),
        ]),
      );

      expect(result.resolver.anchorTimeline(hero), const ResolvedSpan(30, 90));
      expect(result.spans[0], const ResolvedSpan(90, 110));
    });

    test('a non-auto exit is start-anchored, never end-anchored (D3)', () {
      final hero = Anchor('hero');
      final result = resolvePlan(
        single([
          element(
            'title',
            anchor: hero,
            animations: [anim(timing: const Tween(Time.frames(30)))],
          ),
          element(
            'subtitle',
            animations: [
              anim(
                phase: AnimationPhase.exit,
                at: Trigger.whenEnds(hero),
                timing: const Tween(Time.frames(20)),
              ),
            ],
          ),
        ]),
      );

      // Start = anchored end (30); end = start + duration — not windowEnd-delay.
      expect(result.spans[1], const ResolvedSpan(30, 50));
    });

    test('sceneStart fires at the scene start plus delay, even inside a window', () {
      final result = resolvePlan(
        single([
          element(
            'card',
            window: 2.seconds.to(8.seconds),
            animations: [
              anim(
                at: Trigger.sceneStart,
                delay: 1.seconds,
                timing: const Tween(Time.frames(30)),
              ),
            ],
          ),
        ]),
      );

      // Raw math: the span may precede the window; bounds checks are 3.4 (D9).
      expect(result.spans[0], const ResolvedSpan(30, 60));
    });

    test('sceneEnd end-anchors regardless of phase: end = sceneEnd − delay (D4)', () {
      final result = resolvePlan(
        single([
          element(
            'outro',
            animations: [
              anim(
                at: Trigger.sceneEnd,
                delay: 1.seconds,
                timing: const Tween(Time.frames(30)),
              ),
              anim(
                phase: AnimationPhase.during,
                at: Trigger.sceneEnd,
                delay: 1.seconds,
                timing: const Tween(Time.frames(30)),
              ),
            ],
          ),
        ]),
      );

      expect(result.spans[0], const ResolvedSpan(240, 270));
      expect(result.spans[1], const ResolvedSpan(240, 270));
    });

    test('at(t) resolves against the nearest scope (D5)', () {
      final result = resolvePlan(
        single([
          element(
            'windowed',
            window: 2.seconds.to(8.seconds),
            animations: [
              anim(at: const Trigger.at(Time.seconds(1)), timing: const Tween(Time.frames(20))),
              anim(at: Trigger.at(0.5.relative), timing: const Tween(Time.frames(20))),
            ],
          ),
          element(
            'bare',
            animations: [
              anim(at: const Trigger.at(Time.seconds(1)), timing: const Tween(Time.frames(20))),
            ],
          ),
        ]),
      );

      // Windowed: offsets from frame 60; 0.5.relative of the 180-frame window.
      expect(result.spans[0], const ResolvedSpan(90, 110));
      expect(result.spans[1], const ResolvedSpan(150, 170));
      // Bare: offsets from the scene start.
      expect(result.spans[2], const ResolvedSpan(30, 50));
    });

    test('a mixed graph resolves to a stable snapshot', () {
      final bg = Anchor('bg');
      final card = Anchor('card');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element(
                'bg',
                anchor: bg,
                animations: [anim(timing: const Tween(Time.frames(30)))],
              ),
              element(
                'title',
                animations: [
                  anim(at: Trigger.whenStarts(bg), timing: const Tween(Time.frames(24))),
                  anim(at: Trigger.previous, timing: const Tween(Time.frames(12))),
                ],
              ),
            ],
          ),
          scene(
            'two',
            duration: 6.seconds,
            elements: [
              element(
                'card',
                anchor: card,
                window: 1.seconds.to(5.seconds),
                animations: [
                  anim(timing: const Tween(Time.frames(30))),
                  anim(phase: AnimationPhase.exit, timing: const Tween(Time.frames(30))),
                ],
              ),
              element(
                'cta',
                animations: [
                  anim(at: Trigger.whenEnds(card), timing: const Tween(Time.frames(24))),
                ],
              ),
            ],
          ),
        ],
      );

      final first = resolvePlan(plan);
      final second = resolvePlan(plan);

      expect(first.spans, {
        0: const ResolvedSpan(0, 30), // bg enter at scene one start
        1: const ResolvedSpan(0, 24), // title whenStarts(bg)
        2: const ResolvedSpan(24, 36), // title previous chain
        3: const ResolvedSpan(150, 180), // card enter at its window start
        4: const ResolvedSpan(240, 270), // card auto exit, end-anchored
        5: const ResolvedSpan(270, 294), // cta after(card) union end
      });
      expect(second.spans, first.spans);
    });
  });
}
