import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/resolver/composition_resolver.dart';
import 'package:fluvie/src/timing/timeline/debug_timeline.dart';

import '../helpers/plan_builders.dart';

void main() {
  group('resolveComposition with transitions (D3/D4/D5)', () {
    test('an overlap boundary starts scene 2 early and shortens the total', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene('first', duration: 2.seconds),
            scene(
              'second',
              duration: 2.seconds,
              elements: [
                element('logo', animations: [anim(timing: const Tween(Time.frames(15)))]),
              ],
            ),
          ],
          transitions: [Transition.crossFade(15.frames)],
        ),
      );

      // Scene 2 starts 15 frames early (60 - 15 = 45); its auto enter starts there.
      expect(timeline.rows.single.startFrame, 45);
      expect(timeline.rows.single.endFrame, 60);
      expect(timeline.totalFrames, 120 - 15);
      expect(timeline.warnings, isEmpty);
    });

    test('a Trigger.after chain across an overlapped boundary uses the adjusted offsets', () {
      final title = Anchor('title');
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'first',
              duration: 2.seconds,
              elements: [
                element(
                  'title',
                  anchor: title,
                  animations: [
                    anim(at: Trigger.at(40.frames), timing: const Tween(Time.frames(10))),
                  ],
                ),
              ],
            ),
            scene(
              'second',
              duration: 2.seconds,
              elements: [
                element(
                  'badge',
                  animations: [
                    anim(at: Trigger.after(title), timing: const Tween(Time.frames(10))),
                  ],
                ),
              ],
            ),
          ],
          transitions: [Transition.crossFade(15.frames)],
        ),
      );

      // The title ends at frame 50, inside the blend window [45, 60); the
      // badge lives in scene 2's adjusted window [45, 105) and chains at 50.
      final badge = timeline.rowsFor('badge').single;
      expect(badge.startFrame, 50);
      expect(badge.endFrame, 60);
      expect(timeline.warnings, isEmpty);
    });

    test('a non-overlap plan resolves byte-identically to a transition-less plan (D3)', () {
      final scenes = [
        scene(
          'first',
          duration: 2.seconds,
          elements: [
            element('a', animations: [anim(timing: const Tween(Time.frames(20)))]),
          ],
        ),
        scene(
          'second',
          duration: 3.seconds,
          elements: [
            element('b', animations: [anim(timing: const Tween(Time.frames(20)))]),
          ],
        ),
      ];
      final plain = resolveComposition(composition(scenes: scenes));
      final held = resolveComposition(
        composition(
          scenes: scenes,
          transitions: [Transition.crossFade(15.frames, overlap: false)],
        ),
      );

      expect(held.rows, plain.rows);
      expect(held.totalFrames, plain.totalFrames);
      expect(held.warnings, plain.warnings);
    });

    test('an explicit empty transitions list is the all-cut default (no drift, D5)', () {
      final scenes = [
        scene(
          'first',
          duration: 2.seconds,
          elements: [
            element('a', animations: [anim(timing: const Tween(Time.frames(20)))]),
          ],
        ),
        scene('second', duration: 3.seconds),
      ];
      final defaulted = resolveComposition(composition(scenes: scenes));
      // The explicit empty list IS the point of this test, redundant or not.
      // ignore: avoid_redundant_argument_values
      final explicit = resolveComposition(composition(scenes: scenes, transitions: const []));

      expect(explicit.rows, defaulted.rows);
      expect(explicit.totalFrames, defaulted.totalFrames);
    });

    test('mixed-transition plan: the debugTimeline snapshot pins the adjusted offsets', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'one',
              duration: 2.seconds,
              elements: [
                element('a', animations: [anim(timing: const Tween(Time.frames(20)))]),
              ],
            ),
            scene(
              'two',
              duration: 2.seconds,
              elements: [
                element('b', animations: [anim(timing: const Tween(Time.frames(20)))]),
              ],
            ),
            scene(
              'three',
              duration: 45.frames,
              elements: [
                element('c', animations: [anim(timing: const Tween(Time.frames(20)))]),
              ],
            ),
          ],
          transitions: [
            Transition.crossFade(15.frames),
            Transition.wipe(10.frames, overlap: false),
          ],
        ),
      );

      expect(
        debugTimeline(timeline),
        'owner | label | phase | start | end | frames\n'
        '------+-------+-------+-------+-----+-------\n'
        'a     | -     | enter |     0 |  20 |     20\n'
        'b     | -     | enter |    45 |  65 |     20\n'
        'c     | -     | enter |   105 | 125 |     20\n'
        'total: 150 frames @ 30 fps\n',
      );
    });
  });
}
