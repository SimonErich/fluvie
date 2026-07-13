import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

/// A deck of bare plans: [steps] step counts per slide.
List<SlidePlan> _deck(List<int> steps) => [
  for (var s = 0; s < steps.length; s++)
    SlidePlan(
      sceneIndex: s,
      steps: [
        for (var k = 0; k < steps[s]; k++) SlideStep(index: k, stops: const [], entranceFrames: 12),
      ],
    ),
];

ProviderContainer _present(List<int> steps) {
  final container = ProviderContainer(
    overrides: [slidePlansProvider.overrideWithValue(_deck(steps))],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('PresentationPosition', () {
    test('orders by slide, then step', () {
      expect(
        const PresentationPosition(0, 1).compareTo(const PresentationPosition(0, 2)) < 0,
        isTrue,
      );
      expect(
        const PresentationPosition(0, 9).compareTo(const PresentationPosition(1, 0)) < 0,
        isTrue,
      );
      expect(const PresentationPosition(1, 2).compareTo(const PresentationPosition(1, 2)), 0);
    });

    test('is a value', () {
      expect(const PresentationPosition(1, 2), const PresentationPosition(1, 2));
      expect(const PresentationPosition(1, 2).hashCode, const PresentationPosition(1, 2).hashCode);
      expect(const PresentationPosition(1, 2), isNot(const PresentationPosition(2, 1)));
      expect(const PresentationPosition(1, 2).toString(), 'PresentationPosition(1.2)');
    });
  });

  group('traversal', () {
    test('starts at the first position, landed instantly', () {
      final container = _present([3, 2]);
      final state = container.read(presentationControllerProvider);
      expect(state.position, const PresentationPosition(0, 0));
      expect(state.lastMove, NavigationKind.instant);
    });

    test('next walks the flat order across steps and slides', () {
      final container = _present([3, 2]);
      final controller = container.read(presentationControllerProvider.notifier);
      final walked = <PresentationPosition>[];
      for (var i = 0; i < 5; i++) {
        controller.next();
        walked.add(container.read(presentationControllerProvider).position);
      }
      expect(walked, const [
        PresentationPosition(0, 1),
        PresentationPosition(0, 2),
        PresentationPosition(1, 0),
        PresentationPosition(1, 1),
        PresentationPosition(1, 1), // the end: next is a no-op
      ]);
      expect(container.read(presentationControllerProvider).lastMove, NavigationKind.forward);
    });

    test('back walks the flat order in reverse, landing instantly', () {
      final container = _present([3, 2]);
      final controller = container.read(presentationControllerProvider.notifier)
        ..jumpToStep(1, 0)
        ..back();
      final state = container.read(presentationControllerProvider);
      // Back from a slide's base step lands on the previous slide's LAST step.
      expect(state.position, const PresentationPosition(0, 2));
      expect(state.lastMove, NavigationKind.instant);
      controller
        ..back()
        ..back();
      expect(
        container.read(presentationControllerProvider).position,
        const PresentationPosition(0, 0),
      );
      controller.back();
      expect(
        container.read(presentationControllerProvider).position,
        const PresentationPosition(0, 0),
      );
    });

    test('the edges answer canGoNext and canGoBack', () {
      final container = _present([1, 2]);
      final controller = container.read(presentationControllerProvider.notifier);
      expect(controller.canGoBack, isFalse);
      expect(controller.canGoNext, isTrue);
      controller
        ..next()
        ..next();
      expect(
        container.read(presentationControllerProvider).position,
        const PresentationPosition(1, 1),
      );
      expect(controller.canGoNext, isFalse);
      expect(controller.canGoBack, isTrue);
    });

    test('nextPosition describes what the next input produces', () {
      final container = _present([2, 1]);
      final controller = container.read(presentationControllerProvider.notifier);
      expect(controller.nextPosition, const PresentationPosition(0, 1));
      controller.next();
      expect(controller.nextPosition, const PresentationPosition(1, 0));
      controller.next();
      expect(controller.nextPosition, isNull);
    });
  });

  group('jumps', () {
    test('jumpToSlide lands on step 0 instantly', () {
      final container = _present([3, 2, 2]);
      container.read(presentationControllerProvider.notifier)
        ..next()
        ..jumpToSlide(2);
      final state = container.read(presentationControllerProvider);
      expect(state.position, const PresentationPosition(2, 0));
      expect(state.lastMove, NavigationKind.instant);
    });

    test('jumpToStep clamps to the slide and its steps', () {
      final container = _present([3, 2]);
      final controller = container.read(presentationControllerProvider.notifier)..jumpToStep(1, 5);
      expect(
        container.read(presentationControllerProvider).position,
        const PresentationPosition(1, 1),
      );
      controller.jumpToStep(9, 0);
      expect(
        container.read(presentationControllerProvider).position,
        const PresentationPosition(1, 0),
      );
      controller.jumpToStep(-1, -1);
      expect(
        container.read(presentationControllerProvider).position,
        const PresentationPosition(0, 0),
      );
    });

    test('the state is a value and the deck provider demands an override', () {
      const state = PresentationState(
        position: PresentationPosition(1, 2),
        lastMove: NavigationKind.forward,
      );
      expect(
        state,
        const PresentationState(
          position: PresentationPosition(1, 2),
          lastMove: NavigationKind.forward,
        ),
      );
      expect(
        state.hashCode,
        const PresentationState(
          position: PresentationPosition(1, 2),
          lastMove: NavigationKind.forward,
        ).hashCode,
      );
      expect(
        state,
        isNot(
          const PresentationState(
            position: PresentationPosition(1, 2),
            lastMove: NavigationKind.instant,
          ),
        ),
      );
      expect(state.toString(), 'PresentationState(PresentationPosition(1.2), forward)');

      final bare = ProviderContainer();
      addTearDown(bare.dispose);
      expect(() => bare.read(slidePlansProvider), throwsUnimplementedError);
    });

    test('derived counts read from the deck', () {
      final container = _present([3, 2]);
      final controller = container.read(presentationControllerProvider.notifier);
      expect(controller.totalSlides, 2);
      expect(controller.stepsInCurrentSlide, 3);
      controller.jumpToSlide(1);
      expect(controller.stepsInCurrentSlide, 2);
    });
  });
}
