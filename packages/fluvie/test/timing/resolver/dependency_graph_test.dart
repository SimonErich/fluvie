import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/resolver/anchor_registry.dart';
import 'package:fluvie/src/timing/resolver/dependency_graph.dart';

import '../helpers/plan_builders.dart';

void main() {
  List<int> topoIndices(CompositionPlan plan) {
    final graph = DependencyGraph.fromRegistry(AnchorRegistry.collect(plan));
    return graph.topologicalOrder().map((n) => n.index).toList();
  }

  group('DependencyGraph edges', () {
    test('independent nodes come out in declaration order', () {
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('a', animations: [anim(), anim()]),
              element('b', animations: [anim()]),
            ],
          ),
          scene(
            'two',
            duration: 6.seconds,
            elements: [
              element('c', animations: [anim()]),
            ],
          ),
        ],
      );

      expect(topoIndices(plan), [0, 1, 2, 3]);
    });

    test('sceneStart, sceneEnd, at, and beat triggers add no edges', () {
      final hero = Anchor('hero');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element(
                'free',
                animations: [
                  anim(at: Trigger.sceneEnd),
                  anim(at: const Trigger.at(Time.frames(10))),
                  // An unregistered beat track must not be treated as an
                  // anchor dependency — grids are looked up at resolve time.
                  anim(at: Trigger.beat(track: Anchor('audio'))),
                  anim(at: Trigger.sceneStart),
                ],
              ),
              element('anchored', anchor: hero, animations: [anim()]),
            ],
          ),
        ],
      );

      expect(topoIndices(plan), [0, 1, 2, 3, 4]);
    });

    test('after(anchor) orders every node of the anchored element first', () {
      final hero = Anchor('hero');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('follower', animations: [anim(at: Trigger.after(hero))]),
              element('leader', anchor: hero, animations: [anim(), anim()]),
            ],
          ),
        ],
      );

      expect(topoIndices(plan), [1, 2, 0]);
    });

    test("whenStarts(anchor) orders the anchored element's nodes first", () {
      final hero = Anchor('hero');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('follower', animations: [anim(at: Trigger.whenStarts(hero))]),
              element('leader', anchor: hero, animations: [anim(), anim()]),
            ],
          ),
        ],
      );

      expect(topoIndices(plan), [1, 2, 0]);
    });

    test('previous on the first animation of an element throws (D6)', () {
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('title', animations: [anim(at: Trigger.previous)]),
            ],
          ),
        ],
      );

      expect(
        () => DependencyGraph.fromRegistry(AnchorRegistry.collect(plan)),
        throwsA(
          isA<FluvieTimingError>()
              .having((e) => e.message, 'message', contains('title'))
              .having((e) => e.message, 'message', contains('first animation')),
        ),
      );
    });
  });

  group('DependencyGraph.topologicalOrder', () {
    test('is deterministic: the same plan yields the same order every time', () {
      final hero = Anchor('hero');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('late', animations: [anim(at: Trigger.after(hero))]),
              element('leader', anchor: hero, animations: [anim()]),
              element(
                'free',
                animations: [
                  anim(),
                  anim(at: Trigger.previous),
                ],
              ),
            ],
          ),
        ],
      );

      final first = topoIndices(plan);
      for (var run = 0; run < 5; run++) {
        expect(topoIndices(plan), first);
      }
    });

    test('a diamond resolves dependencies first with declaration-order tiebreak', () {
      final a = Anchor('a');
      final b = Anchor('b');
      // Declaration order: D(0) after b, B(1) after a, C(2) after a, A(3).
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('d', animations: [anim(at: Trigger.after(b))]),
              element(
                'b',
                anchor: b,
                animations: [anim(at: Trigger.after(a))],
              ),
              element('c', animations: [anim(at: Trigger.after(a))]),
              element('a', anchor: a, animations: [anim()]),
            ],
          ),
        ],
      );

      // A first; then B; then D beats C on declaration index; then C.
      expect(topoIndices(plan), [3, 1, 0, 2]);
    });
  });

  group('DependencyGraph cycle detection', () {
    test('a two-node cycle throws naming both anchors', () {
      final alpha = Anchor('alpha');
      final beta = Anchor('beta');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element(
                'first',
                anchor: alpha,
                animations: [anim(at: Trigger.after(beta))],
              ),
              element(
                'second',
                anchor: beta,
                animations: [anim(at: Trigger.after(alpha))],
              ),
            ],
          ),
        ],
      );

      expect(
        () => topoIndices(plan),
        throwsA(
          isA<FluvieTimingError>()
              .having((e) => e.anchors, 'anchors', [alpha, beta])
              .having((e) => e.message, 'message', contains('alpha → beta → alpha')),
        ),
      );
    });

    test('a self-referencing element throws naming its own anchor', () {
      final selfish = Anchor('selfish');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element(
                'loop',
                anchor: selfish,
                animations: [anim(at: Trigger.after(selfish))],
              ),
            ],
          ),
        ],
      );

      expect(
        () => topoIndices(plan),
        throwsA(
          isA<FluvieTimingError>()
              .having((e) => e.anchors, 'anchors', [selfish])
              .having((e) => e.message, 'message', contains('selfish → selfish')),
        ),
      );
    });

    test('a three-node cycle names all three participants', () {
      final a = Anchor('a');
      final b = Anchor('b');
      final c = Anchor('c');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element(
                'ea',
                anchor: a,
                animations: [anim(at: Trigger.after(c))],
              ),
              element(
                'eb',
                anchor: b,
                animations: [anim(at: Trigger.after(a))],
              ),
              element(
                'ec',
                anchor: c,
                animations: [anim(at: Trigger.after(b))],
              ),
            ],
          ),
        ],
      );

      expect(
        () => topoIndices(plan),
        throwsA(
          isA<FluvieTimingError>()
              .having((e) => e.anchors, 'anchors', [a, b, c])
              .having((e) => e.message, 'message', contains('a → b → c → a')),
        ),
      );
    });

    test('cycle names fall back to the ownerId when the anchor is unnamed', () {
      final left = Anchor();
      final right = Anchor();
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element(
                'left',
                anchor: left,
                animations: [anim(at: Trigger.after(right))],
              ),
              element(
                'right',
                anchor: right,
                animations: [anim(at: Trigger.after(left))],
              ),
            ],
          ),
        ],
      );

      expect(
        () => topoIndices(plan),
        throwsA(
          isA<FluvieTimingError>()
              .having((e) => e.anchors, 'anchors', [left, right])
              .having((e) => e.message, 'message', contains('left → right → left')),
        ),
      );
    });

    test('whenStarts participates in cycles exactly like after', () {
      final alpha = Anchor('alpha');
      final beta = Anchor('beta');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element(
                'first',
                anchor: alpha,
                animations: [anim(at: Trigger.whenStarts(beta))],
              ),
              element(
                'second',
                anchor: beta,
                animations: [anim(at: Trigger.whenStarts(alpha))],
              ),
            ],
          ),
        ],
      );

      expect(
        () => topoIndices(plan),
        throwsA(isA<FluvieTimingError>().having((e) => e.anchors, 'anchors', [alpha, beta])),
      );
    });

    test('a cycle through every element terminates with an error, never hangs', () {
      const count = 12;
      final anchors = [for (var i = 0; i < count; i++) Anchor('n$i')];
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              for (var i = 0; i < count; i++)
                element(
                  'e$i',
                  anchor: anchors[i],
                  animations: [anim(at: Trigger.after(anchors[(i + 1) % count]))],
                ),
            ],
          ),
        ],
      );

      expect(
        () => topoIndices(plan),
        throwsA(
          isA<FluvieTimingError>().having((e) => e.anchors, 'anchors', hasLength(count)),
        ),
      );
    });
  });
}
