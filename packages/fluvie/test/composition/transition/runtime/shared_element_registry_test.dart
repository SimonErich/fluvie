import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_scope.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';

SharedSlotHandle _handle(Anchor anchor, int sceneIndex) =>
    SharedSlotHandle(anchor: anchor, sceneIndex: sceneIndex, child: const SizedBox());

void main() {
  group('SharedElementRegistry pairing', () {
    test('pairAtBoundary returns the source/target handles of a complete pair', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      final source = _handle(logo, 0);
      final target = _handle(logo, 1);
      registry
        ..register(source)
        ..register(target);

      final pair = registry.pairAtBoundary(0);
      expect(pair, isNotNull);
      expect(pair!.source, same(source));
      expect(pair.target, same(target));
      expect(pair.anchor, same(logo));
    });

    test('a boundary with no pair returns null', () {
      final registry = SharedElementRegistry()..register(_handle(Anchor('solo'), 0));
      expect(registry.pairAtBoundary(0), isNull);
    });

    test('a pair spanning a different boundary is null for the asked one', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      registry
        ..register(_handle(logo, 1))
        ..register(_handle(logo, 2));
      expect(registry.pairAtBoundary(0), isNull);
      expect(registry.pairAtBoundary(1), isNotNull);
    });
  });

  group('SharedElementRegistry.validate (D10)', () {
    test('a valid adjacent pair validates', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      registry
        ..register(_handle(logo, 0))
        ..register(_handle(logo, 1))
        ..validate(4);
      expect(registry.isValidated, isTrue);
    });

    test('an anchor in only one scene throws naming it and the scene', () {
      final registry = SharedElementRegistry()..register(_handle(Anchor('logo'), 0));
      expect(
        () => registry.validate(2),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            allOf(contains('logo'), contains('one scene'), contains('scenes[0]')),
          ),
        ),
      );
    });

    test('an anchor in three or more scenes throws naming all of them', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      registry
        ..register(_handle(logo, 0))
        ..register(_handle(logo, 1))
        ..register(_handle(logo, 2));
      expect(
        () => registry.validate(4),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('logo'),
              contains('scenes[0]'),
              contains('scenes[1]'),
              contains('scenes[2]'),
            ),
          ),
        ),
      );
    });

    test('two non-adjacent scenes throw the cross-one-boundary error', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      registry
        ..register(_handle(logo, 0))
        ..register(_handle(logo, 2));
      expect(
        () => registry.validate(4),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            allOf(contains('logo'), contains('one boundary')),
          ),
        ),
      );
    });

    test('an adjacent pair across a cut boundary validates (inert, D10)', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      registry
        ..register(_handle(logo, 0))
        ..register(_handle(logo, 1))
        // A cut boundary still pairs adjacent scenes; validate accepts it.
        ..validate(2);
      expect(registry.isValidated, isTrue);
    });

    test('validation carries the Anchor instances on the error', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      registry.register(_handle(logo, 0));
      try {
        registry.validate(2);
        fail('expected a FluvieTimingError');
      } on FluvieTimingError catch (error) {
        expect(error.anchors, contains(logo));
      }
    });
  });

  group('SharedElementRegistry lifecycle', () {
    test('a new anchor registering after validation throws the stable-set error', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      registry
        ..register(_handle(logo, 0))
        ..register(_handle(logo, 1))
        ..validate(2);
      expect(
        () => registry.register(_handle(Anchor('late'), 0)),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            contains('after the plan was resolved'),
          ),
        ),
      );
    });

    test('re-registering a known anchor after validation is allowed', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      final source = _handle(logo, 0);
      registry
        ..register(source)
        ..register(_handle(logo, 1))
        ..validate(2)
        // A known anchor relisting (a remount of the same slot) is fine.
        ..register(_handle(logo, 0));
      expect(registry.isValidated, isTrue);
    });

    test('unregister then re-register the same handle is allowed pre-validation', () {
      final registry = SharedElementRegistry();
      final handle = _handle(Anchor('logo'), 0);
      registry
        ..register(handle)
        ..unregister(handle)
        ..register(handle);
      expect(registry.isValidated, isFalse);
    });

    test('reset clears the registrations and the validated flag', () {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      registry
        ..register(_handle(logo, 0))
        ..register(_handle(logo, 1))
        ..validate(2)
        ..reset();
      expect(registry.isValidated, isFalse);
      expect(registry.pairAtBoundary(0), isNull);
    });
  });

  group('SharedElementScope', () {
    testWidgets('maybeOf returns the nearest registry and scene index', (tester) async {
      final registry = SharedElementRegistry();
      SharedElementScope? seen;
      await tester.pumpWidget(
        SharedElementScope(
          registry: registry,
          sceneIndex: 3,
          child: Builder(
            builder: (context) {
              seen = SharedElementScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.registry, same(registry));
      expect(seen!.sceneIndex, 3);
    });

    testWidgets('maybeOf is null without an enclosing scope', (tester) async {
      var seenCount = 0;
      SharedElementScope? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seenCount++;
            seen = SharedElementScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(seenCount, 1);
      expect(seen, isNull);
    });
  });
}
