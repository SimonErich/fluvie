// Shared chains: a hero that runs through more than one cut. A chain is any
// contiguous run of scenes; a gap in it is not a chain, and one scene is not
// a hero at all.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';

SharedElementRegistry _registry(Anchor anchor, List<int> scenes) {
  final registry = SharedElementRegistry();
  for (final scene in scenes) {
    registry.register(
      SharedSlotHandle(
        anchor: anchor,
        sceneIndex: scene,
        child: SizedBox(width: scene.toDouble() + 1),
      ),
    );
  }
  return registry;
}

void main() {
  group('what a chain may be', () {
    test('a pair, which is the shortest hero there is', () {
      expect(() => _registry(Anchor('hero'), [0, 1]).validate(2), returnsNormally);
    });

    test('a run of three, morphing through two cuts', () {
      expect(() => _registry(Anchor('hero'), [0, 1, 2]).validate(3), returnsNormally);
    });

    test('a run of five', () {
      expect(() => _registry(Anchor('hero'), [0, 1, 2, 3, 4]).validate(5), returnsNormally);
    });

    test('a run that starts anywhere, not only at the first scene', () {
      expect(() => _registry(Anchor('hero'), [2, 3, 4]).validate(6), returnsNormally);
    });

    test('a run registered out of order, because registration order is build order', () {
      expect(() => _registry(Anchor('hero'), [3, 1, 2]).validate(5), returnsNormally);
    });
  });

  group('what a chain may not be', () {
    test('one scene, which is not a morph but a hero with nothing to morph to', () {
      expect(
        () => _registry(Anchor('hero'), [1]).validate(3),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            contains('one scene'),
          ),
        ),
      );
    });

    test('a run with a gap in it', () {
      // Scenes 0 and 2 with nothing in 1: the hero would vanish for a scene
      // and come back, which is two morphs pretending to be one.
      expect(
        () => _registry(Anchor('hero'), [0, 2]).validate(3),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            contains('contiguous'),
          ),
        ),
      );
    });

    test('a long run with a gap in the middle', () {
      expect(
        () => _registry(Anchor('hero'), [0, 1, 3, 4]).validate(5),
        throwsA(isA<FluvieTimingError>()),
      );
    });
  });

  group('the pair at a boundary', () {
    test('is the two ends of the cut, taken from anywhere in the chain', () {
      // A four-scene chain has three internal boundaries, and each one has to
      // hand back its own pair rather than only the first.
      final anchor = Anchor('hero');
      final registry = _registry(anchor, [0, 1, 2, 3]);

      for (final boundary in [0, 1, 2]) {
        final pair = registry.pairAtBoundary(boundary);
        expect(pair, isNotNull, reason: 'boundary $boundary');
        expect(pair!.anchor, same(anchor));
        expect((pair.source.child as SizedBox).width, boundary + 1);
        expect((pair.target.child as SizedBox).width, boundary + 2);
      }
    });

    test('is nothing at a boundary the chain does not cross', () {
      final registry = _registry(Anchor('hero'), [2, 3]);

      expect(registry.pairAtBoundary(0), isNull);
      expect(registry.pairAtBoundary(1), isNull);
      expect(registry.pairAtBoundary(2), isNotNull);
    });

    test('is still nothing where no anchor has a slot at all', () {
      expect(SharedElementRegistry().pairAtBoundary(0), isNull);
    });

    test('finds each chain separately when two run at once', () {
      final first = Anchor('title');
      final second = Anchor('logo');
      final registry = SharedElementRegistry();
      for (final scene in [0, 1, 2]) {
        registry.register(
          SharedSlotHandle(anchor: first, sceneIndex: scene, child: const SizedBox(width: 1)),
        );
      }
      for (final scene in [1, 2]) {
        registry.register(
          SharedSlotHandle(anchor: second, sceneIndex: scene, child: const SizedBox(width: 2)),
        );
      }

      expect(registry.pairAtBoundary(0)!.anchor, same(first));
      // Both chains cross boundary 1; the first anchor registered wins, which
      // is stable rather than arbitrary.
      expect(registry.pairAtBoundary(1), isNotNull);
    });
  });
}
