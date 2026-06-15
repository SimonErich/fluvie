import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/timing/resolver/anchor_registry.dart';

import '../helpers/plan_builders.dart';

void main() {
  group('AnchorRegistry.collect', () {
    test('collects nodes in declaration order across scenes and elements', () {
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('title', animations: [anim(), anim()]),
              element('subtitle', animations: [anim()]),
            ],
          ),
          scene(
            'two',
            duration: 6.seconds,
            elements: [
              element('logo', animations: [anim()]),
            ],
          ),
        ],
      );

      final registry = AnchorRegistry.collect(plan);

      expect(
        registry.nodes.map((n) => n.element.ownerId),
        ['title', 'title', 'subtitle', 'logo'],
      );
      expect(registry.nodes.map((n) => n.index), [0, 1, 2, 3]);
    });

    test('node ids are stable: indices match declaration position on every collect', () {
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('title', animations: [anim(), anim()]),
            ],
          ),
          scene(
            'two',
            duration: 6.seconds,
            elements: [
              element('logo', animations: [anim()]),
            ],
          ),
        ],
      );

      final first = AnchorRegistry.collect(plan);
      final second = AnchorRegistry.collect(plan);

      expect(first.nodes[1].sceneIndex, 0);
      expect(first.nodes[1].elementIndex, 0);
      expect(first.nodes[1].animationIndex, 1);
      expect(first.nodes[2].sceneIndex, 1);
      expect(first.nodes[2].elementIndex, 0);
      expect(first.nodes[2].animationIndex, 0);
      expect(identical(first.nodes[0].element, plan.scenes[0].elements[0]), isTrue);
      expect(identical(first.nodes[0].plan, plan.scenes[0].elements[0].animations[0]), isTrue);
      for (var i = 0; i < first.nodes.length; i++) {
        expect(first.nodes[i].index, second.nodes[i].index);
        expect(first.nodes[i].sceneIndex, second.nodes[i].sceneIndex);
        expect(first.nodes[i].elementIndex, second.nodes[i].elementIndex);
        expect(first.nodes[i].animationIndex, second.nodes[i].animationIndex);
      }
    });

    test("nodesForAnchor returns exactly the anchored element's animations", () {
      final hero = Anchor('hero');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('backdrop', animations: [anim()]),
              element('title', anchor: hero, animations: [anim(), anim()]),
              element('subtitle', animations: [anim()]),
            ],
          ),
        ],
      );

      final registry = AnchorRegistry.collect(plan);
      final nodes = registry.nodesForAnchor(hero);

      expect(registry.isRegistered(hero), isTrue);
      expect(nodes, hasLength(2));
      expect(nodes.map((n) => n.index), [1, 2]);
      for (final node in nodes) {
        expect(identical(node.element, plan.scenes[0].elements[1]), isTrue);
      }
      expect(identical(registry.elementForAnchor(hero), plan.scenes[0].elements[1]), isTrue);
    });

    test('two anchors sharing a debugName stay distinct handles', () {
      final first = Anchor('twin');
      final second = Anchor('twin');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('left', anchor: first, animations: [anim()]),
              element('right', anchor: second, animations: [anim()]),
            ],
          ),
        ],
      );

      final registry = AnchorRegistry.collect(plan);

      expect(registry.nodesForAnchor(first).single.element.ownerId, 'left');
      expect(registry.nodesForAnchor(second).single.element.ownerId, 'right');
    });

    test('a dangling anchor throws a FluvieTimingError naming it', () {
      final ghost = Anchor('ghost');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('title', animations: [anim()]),
            ],
          ),
        ],
      );

      final registry = AnchorRegistry.collect(plan);

      expect(registry.isRegistered(ghost), isFalse);
      expect(
        () => registry.nodesForAnchor(ghost),
        throwsA(
          isA<FluvieTimingError>()
              .having((e) => e.anchors, 'anchors', [ghost])
              .having((e) => e.toString(), 'toString', contains('ghost')),
        ),
      );
      expect(() => registry.elementForAnchor(ghost), throwsA(isA<FluvieTimingError>()));
    });

    test('an anchored element without animations is registered with no nodes', () {
      final still = Anchor('still');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('backdrop', anchor: still),
              element('title', animations: [anim()]),
            ],
          ),
        ],
      );

      final registry = AnchorRegistry.collect(plan);

      expect(registry.isRegistered(still), isTrue);
      expect(registry.nodesForAnchor(still), isEmpty);
      expect(identical(registry.elementForAnchor(still), plan.scenes[0].elements[0]), isTrue);
    });

    test('a labelled animation is discoverable in the node list', () {
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element(
                'title',
                animations: [
                  anim(),
                  anim(label: 'pop'),
                ],
              ),
            ],
          ),
        ],
      );

      final registry = AnchorRegistry.collect(plan);
      final labelled = registry.nodes.singleWhere((n) => n.plan.label == 'pop');

      expect(labelled.index, 1);
      expect(labelled.element.ownerId, 'title');
    });

    test('anchors lists every attached anchor in declaration order', () {
      final first = Anchor('first');
      final second = Anchor('second');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('plain', animations: [anim()]),
              element('left', anchor: first, animations: [anim()]),
            ],
          ),
          scene(
            'two',
            duration: 4.seconds,
            elements: [
              element('right', anchor: second, animations: [anim()]),
            ],
          ),
        ],
      );

      final registry = AnchorRegistry.collect(plan);

      expect(registry.anchors, [first, second]);
    });

    test('anchors is empty when no element is anchored', () {
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('plain', animations: [anim()]),
            ],
          ),
        ],
      );

      expect(AnchorRegistry.collect(plan).anchors, isEmpty);
    });

    test('one anchor attached to two elements throws a FluvieTimingError', () {
      final shared = Anchor('shared');
      final plan = composition(
        scenes: [
          scene(
            'one',
            duration: 4.seconds,
            elements: [
              element('left', anchor: shared, animations: [anim()]),
              element('right', anchor: shared, animations: [anim()]),
            ],
          ),
        ],
      );

      expect(
        () => AnchorRegistry.collect(plan),
        throwsA(
          isA<FluvieTimingError>()
              .having((e) => e.anchors, 'anchors', [shared])
              .having((e) => e.message, 'message', contains('right')),
        ),
      );
    });
  });
}
