import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/resolver/composition_resolver.dart';
import 'package:fluvie/src/timing/timeline/timeline_anchor.dart';
import 'package:fluvie/src/timing/timeline/timeline_row.dart';

import 'helpers/plan_builders.dart';
import 'helpers/worked_example.dart';

void main() {
  group('resolveComposition', () {
    test('an empty composition resolves to an empty timeline', () {
      final timeline = resolveComposition(composition(fps: 24));

      expect(timeline.fps, 24);
      expect(timeline.totalFrames, 0);
      expect(timeline.rows, isEmpty);
      expect(timeline.warnings, isEmpty);
    });

    test('totalFrames is the sum of the scene durations', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene('a', duration: 3.seconds),
            scene('b', duration: 4.seconds),
            scene('c', duration: 45.frames),
          ],
        ),
      );

      expect(timeline.totalFrames, 90 + 120 + 45);
    });

    test('scenes mount at running offsets: an auto enter in scene 2 starts there', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene('first', duration: 2.seconds),
            scene(
              'second',
              duration: 2.seconds,
              elements: [
                element('logo', animations: [anim(timing: Tween(15.frames))]),
              ],
            ),
          ],
        ),
      );

      expect(timeline.rows, const [
        TimelineRow(ownerId: 'logo', phase: AnimationPhase.enter, startFrame: 60, endFrame: 75),
      ]);
    });

    test('Trigger.at resolves within its scene, not the video (D5)', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene('first', duration: 2.seconds),
            scene(
              'second',
              duration: 3.seconds,
              elements: [
                element(
                  'badge',
                  animations: [anim(at: Trigger.at(1.seconds), timing: Tween(10.frames))],
                ),
              ],
            ),
          ],
        ),
      );

      expect(timeline.rows.single.startFrame, 60 + 30);
      expect(timeline.rows.single.endFrame, 60 + 40);
    });

    test('rows sort by startFrame, breaking ties in declaration order', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'one',
              duration: 4.seconds,
              elements: [
                element(
                  'late',
                  animations: [anim(at: Trigger.at(20.frames), timing: Tween(10.frames))],
                ),
                element(
                  'early',
                  animations: [anim(at: Trigger.at(10.frames), timing: Tween(10.frames))],
                ),
                element('tie-a', animations: [anim(timing: Tween(10.frames))]),
                element('tie-b', animations: [anim(timing: Tween(10.frames))]),
              ],
            ),
          ],
        ),
      );

      expect(timeline.rows.map((r) => r.ownerId), ['tie-a', 'tie-b', 'early', 'late']);
    });

    test('a relative scene duration is circular and throws, naming the scene (D13)', () {
      expect(
        () => resolveComposition(composition(scenes: [scene('loop', duration: 0.5.relative)])),
        throwsA(
          isA<FluvieTimingError>().having((e) => e.message, 'message', contains("'loop'")),
        ),
      );
    });

    test('a composite duration hiding a relative component also throws (D13)', () {
      expect(
        () => resolveComposition(
          composition(
            scenes: [scene('sum', duration: 1.seconds + 0.5.relative)],
          ),
        ),
        throwsA(isA<FluvieTimingError>()),
      );
    });

    test('a trigger cycle across elements throws, naming the anchors', () {
      final a = Anchor('a');
      final b = Anchor('b');
      expect(
        () => resolveComposition(
          composition(
            scenes: [
              scene(
                'one',
                duration: 2.seconds,
                elements: [
                  element(
                    'first',
                    anchor: a,
                    animations: [anim(at: Trigger.whenEnds(b))],
                  ),
                  element(
                    'second',
                    anchor: b,
                    animations: [anim(at: Trigger.whenEnds(a))],
                  ),
                ],
              ),
            ],
          ),
        ),
        throwsA(isA<FluvieTimingError>().having((e) => e.anchors, 'anchors', [a, b])),
      );
    });

    test('resolution is deterministic: the same plan resolves identically twice', () {
      final plan = workedExample();

      final first = resolveComposition(plan);
      final second = resolveComposition(plan);

      expect(first.rows, second.rows);
      expect(first.warnings, second.warnings);
      expect(first.totalFrames, second.totalFrames);
    });

    test('an animation overrunning its window warns and keeps the raw span (D9)', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'one',
              duration: 2.seconds,
              elements: [
                element(
                  'big',
                  window: Time.zero.to(1.seconds),
                  animations: [anim(label: 'grow', timing: Tween(2.seconds))],
                ),
              ],
            ),
          ],
        ),
      );

      expect(timeline.rows.single.startFrame, 0);
      expect(timeline.rows.single.endFrame, 60);
      expect(timeline.warnings, hasLength(1));
      expect(timeline.warnings.single, contains("'big'"));
      expect(timeline.warnings.single, contains('window'));
    });

    test('a row past the video end warns about the video bounds (D9)', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'only',
              duration: 2.seconds,
              elements: [
                element('straggler', animations: [anim(delay: 3.seconds)]),
              ],
            ),
          ],
        ),
      );

      // Raw span preserved: start = 0 + 90 (delay), default duration 12.
      expect(timeline.rows.single.startFrame, 90);
      expect(timeline.rows.single.endFrame, 102);
      expect(
        timeline.warnings,
        contains(allOf(contains("'straggler'"), contains('video'))),
      );
    });

    test('an exit overrunning backwards keeps its negative start and warns (D9)', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'one',
              duration: 2.seconds,
              elements: [
                element(
                  'rusher',
                  animations: [anim(phase: AnimationPhase.exit, timing: Tween(3.seconds))],
                ),
              ],
            ),
          ],
        ),
      );

      expect(timeline.rows.single.startFrame, -30);
      expect(timeline.rows.single.endFrame, 60);
      expect(
        timeline.warnings,
        contains(allOf(contains("'rusher'"), contains('video'))),
      );
    });

    test('defaults cascade element > scene > video > package (D14)', () {
      final timeline = resolveComposition(
        composition(
          defaults: const Defaults(duration: Time.frames(30)),
          scenes: [
            scene(
              'video-level',
              duration: 2.seconds,
              elements: [
                element('from-video', animations: [anim()]),
                element(
                  'from-element',
                  defaults: const Defaults(duration: Time.frames(10)),
                  animations: [anim()],
                ),
              ],
            ),
            scene(
              'scene-level',
              duration: 2.seconds,
              defaults: const Defaults(duration: Time.frames(20)),
              elements: [
                element('from-scene', animations: [anim()]),
              ],
            ),
          ],
        ),
      );

      expect(timeline.rowsFor('from-video').single.durationFrames, 30);
      expect(timeline.rowsFor('from-element').single.durationFrames, 10);
      expect(timeline.rowsFor('from-scene').single.durationFrames, 20);
    });

    test('the package default duration measures the element window', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'one',
              duration: 10.seconds,
              elements: [
                element('windowed', window: 2.seconds.to(4.seconds), animations: [anim()]),
              ],
            ),
          ],
        ),
      );

      // min(0.2 × 60, 24) = 12 frames, placed at the window start (frame 60).
      expect(timeline.rows.single.startFrame, 60);
      expect(timeline.rows.single.endFrame, 72);
    });

    test('relative durations on a windowed element measure its window', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'one',
              duration: 10.seconds,
              elements: [
                element(
                  'half',
                  window: 2.seconds.to(6.seconds),
                  animations: [anim(timing: Tween(0.5.relative))],
                ),
              ],
            ),
          ],
        ),
      );

      expect(timeline.rows.single.startFrame, 60);
      expect(timeline.rows.single.endFrame, 60 + 60);
    });

    test('the §26 worked example resolves with no warnings to the documented schedule', () {
      final timeline = resolveComposition(workedExample());

      expect(timeline.fps, 30);
      expect(timeline.totalFrames, 300);
      expect(timeline.warnings, isEmpty);
      expect(timeline.rows, const [
        TimelineRow(
          ownerId: 'title',
          label: 'pop',
          phase: AnimationPhase.enter,
          startFrame: 0,
          endFrame: 36,
        ),
        TimelineRow(
          ownerId: 'title',
          label: 'slideFade',
          phase: AnimationPhase.enter,
          startFrame: 39,
          endFrame: 57,
        ),
        TimelineRow(
          ownerId: 'counter',
          label: 'count',
          phase: AnimationPhase.enter,
          startFrame: 90,
          endFrame: 150,
        ),
        TimelineRow(
          ownerId: 'stats-fx',
          label: 'grain',
          phase: AnimationPhase.during,
          startFrame: 90,
          endFrame: 210,
        ),
        TimelineRow(
          ownerId: 'stats-fx',
          label: 'vignette',
          phase: AnimationPhase.during,
          startFrame: 90,
          endFrame: 210,
        ),
        TimelineRow(
          ownerId: 'caption',
          label: 'fadeIn',
          phase: AnimationPhase.enter,
          startFrame: 135,
          endFrame: 159,
        ),
        TimelineRow(
          ownerId: 'outro',
          label: 'blurIn',
          phase: AnimationPhase.enter,
          startFrame: 210,
          endFrame: 228,
        ),
        TimelineRow(
          ownerId: 'outro',
          label: 'float',
          phase: AnimationPhase.during,
          startFrame: 210,
          endFrame: 300,
        ),
        TimelineRow(
          ownerId: 'outro',
          label: 'fadeOut',
          phase: AnimationPhase.exit,
          startFrame: 282,
          endFrame: 300,
        ),
      ]);
    });

    test('the structured anchor egress resolves the worked example logo to frame 0', () {
      final timeline = resolveComposition(workedExample());

      // The §26 logo is an anchored, animation-less hero in scene 'intro'
      // (frame 0): its anchor frame is its window start (decision D7).
      expect(timeline.anchors, const [TimelineAnchor(name: 'logo', frame: 0)]);
    });

    test('an anchored element with animations resolves the anchor to its timeline start', () {
      final badge = Anchor('badge');
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene('first', duration: 2.seconds),
            scene(
              'second',
              duration: 3.seconds,
              elements: [
                element(
                  'badge',
                  anchor: badge,
                  animations: [anim(at: Trigger.at(1.seconds), timing: Tween(10.frames))],
                ),
              ],
            ),
          ],
        ),
      );

      // Scene 2 starts at frame 60; Trigger.at(1s) places the timeline at 90.
      expect(timeline.anchors, const [TimelineAnchor(name: 'badge', frame: 90)]);
    });

    test('an unnamed anchor surfaces its synthetic Anchor# name', () {
      final unnamed = Anchor();
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'one',
              duration: 2.seconds,
              elements: [
                element('hero', anchor: unnamed, animations: [anim()]),
              ],
            ),
          ],
        ),
      );

      expect(timeline.anchors.single.name, startsWith('Anchor#'));
      expect(timeline.anchors.single.frame, 0);
    });

    test('a composition with no anchors resolves to an empty anchor list', () {
      final timeline = resolveComposition(
        composition(
          scenes: [
            scene(
              'one',
              duration: 2.seconds,
              elements: [
                element('plain', animations: [anim()]),
              ],
            ),
          ],
        ),
      );

      expect(timeline.anchors, isEmpty);
    });

    test('the resolver ignores stagger and repeat (D12/D13: runner/widget-level)', () {
      CompositionPlan planWith({Stagger? stagger, Repeat? repeat}) => composition(
        scenes: [
          scene(
            'intro',
            duration: 4.seconds,
            elements: [
              element(
                'title',
                animations: [
                  anim(
                    timing: const Tween(Time.frames(20)),
                    stagger: stagger,
                    repeat: repeat,
                  ),
                  anim(
                    phase: AnimationPhase.during,
                    at: Trigger.previous,
                    stagger: stagger,
                    repeat: repeat,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final plain = resolveComposition(planWith());
      final decorated = resolveComposition(
        planWith(
          stagger: const Stagger.each(Time.ms(80)),
          repeat: const Repeat.forever(yoyo: true),
        ),
      );

      expect(decorated.rows, plain.rows);
      expect(decorated.totalFrames, plain.totalFrames);
      expect(decorated.warnings, plain.warnings);
    });
  });
}
