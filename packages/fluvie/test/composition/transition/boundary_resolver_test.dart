import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/boundary_resolver.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';

void main() {
  group('resolveBoundaryTransitions (D5, §12)', () {
    final fade = Transition.crossFade(0.5.seconds);
    final wipe = Transition.wipe(0.4.seconds);
    final zoom = Transition.zoom(0.6.seconds);

    test('the video default fills every boundary with no per-scene opinion', () {
      final result = resolveBoundaryTransitions(
        scenes: const [
          (enter: null, exit: null),
          (enter: null, exit: null),
          (enter: null, exit: null),
        ],
        videoDefault: fade,
      );
      expect(result, [fade, fade]);
    });

    test("the incoming scene's enter beats the outgoing exit and the default", () {
      final result = resolveBoundaryTransitions(
        scenes: [
          const (enter: null, exit: null),
          (enter: wipe, exit: null),
        ],
        videoDefault: fade,
      );
      expect(result, [wipe]);
    });

    test("the outgoing scene's exit beats the video default", () {
      final result = resolveBoundaryTransitions(
        scenes: [
          (enter: null, exit: zoom),
          const (enter: null, exit: null),
        ],
        videoDefault: fade,
      );
      expect(result, [zoom]);
    });

    test('enter wins even when both enter and exit are set', () {
      final result = resolveBoundaryTransitions(
        scenes: [
          (enter: null, exit: zoom),
          (enter: wipe, exit: fade),
        ],
        videoDefault: fade,
      );
      // boundary 0: scenes[1].enter (wipe) ?? scenes[0].exit (zoom) -> wipe
      expect(result, [wipe]);
    });

    test('an explicit cut() enter suppresses the video default to a hard cut', () {
      final result = resolveBoundaryTransitions(
        scenes: [
          const (enter: null, exit: null),
          (enter: const Transition.cut(), exit: null),
        ],
        videoDefault: fade,
      );
      expect(result, [const Transition.cut()]);
    });

    test('an explicit cut() exit suppresses the video default to a hard cut', () {
      final result = resolveBoundaryTransitions(
        scenes: [
          (enter: null, exit: const Transition.cut()),
          const (enter: null, exit: null),
        ],
        videoDefault: fade,
      );
      expect(result, [const Transition.cut()]);
    });

    test('all-null scenes with no default leave every boundary null', () {
      final result = resolveBoundaryTransitions(
        scenes: const [
          (enter: null, exit: null),
          (enter: null, exit: null),
        ],
      );
      expect(result, [null]);
    });

    test('a single scene has no boundaries', () {
      final result = resolveBoundaryTransitions(
        scenes: const [(enter: null, exit: null)],
        videoDefault: fade,
      );
      expect(result, isEmpty);
    });

    test('mixed scenes resolve each boundary independently', () {
      final result = resolveBoundaryTransitions(
        scenes: [
          const (enter: null, exit: null),
          (enter: wipe, exit: null), // boundary 0 -> wipe
          const (enter: null, exit: null), // boundary 1 -> default fade
        ],
        videoDefault: fade,
      );
      expect(result, [wipe, fade]);
    });

    test('the result length is always scenes - 1', () {
      final result = resolveBoundaryTransitions(
        scenes: const [
          (enter: null, exit: null),
          (enter: null, exit: null),
          (enter: null, exit: null),
          (enter: null, exit: null),
        ],
        videoDefault: fade,
      );
      expect(result, hasLength(3));
    });
  });
}
