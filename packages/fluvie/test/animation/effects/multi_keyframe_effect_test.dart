import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effects/multi_keyframe_effect.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';

void main() {
  const stops = [Keyframe(opacity: 0), Keyframe(opacity: 1), Keyframe(opacity: 0.5)];
  const effect = MultiKeyframeEffect(stops);

  group('even spacing (default)', () {
    test('p 0, 0.5, and 1 hit the three stops exactly', () {
      expect(effect.keyframeAt(0).opacity, 0);
      expect(effect.keyframeAt(0.5).opacity, 1);
      expect(effect.keyframeAt(1).opacity, 0.5);
    });

    test('mid-segment lerps linearly by default', () {
      expect(effect.keyframeAt(0.25).opacity, closeTo(0.5, 1e-12));
      expect(effect.keyframeAt(0.75).opacity, closeTo(0.75, 1e-12));
    });

    test('progress outside [0, 1] holds the boundary stops', () {
      expect(effect.keyframeAt(-0.2).opacity, 0);
      expect(effect.keyframeAt(1.2).opacity, 0.5);
    });
  });

  group('explicit stop fractions (D17)', () {
    test('custom fractions reposition the mid stop', () {
      final mid = effect.keyframeAt(0.8, stopFractions: const [0, 0.8, 1]);
      expect(mid.opacity, 1);
      // Halfway through the stretched first segment.
      expect(
        effect.keyframeAt(0.4, stopFractions: const [0, 0.8, 1]).opacity,
        closeTo(0.5, 1e-12),
      );
    });

    test('p 0 with explicit fractions starting at 0 hits the first stop', () {
      expect(effect.keyframeAt(0, stopFractions: const [0, 0.8, 1]).opacity, 0);
    });

    test('non-increasing fractions assert', () {
      expect(
        () => effect.keyframeAt(0.5, stopFractions: const [0, 0.9, 0.8]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('fraction-count mismatch asserts', () {
      expect(
        () => effect.keyframeAt(0.5, stopFractions: const [0, 1]),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('per-segment easing', () {
    test('easings[i] shapes segment i; later segments stay linear', () {
      const eased = MultiKeyframeEffect(stops, easings: [Ease.snappy, Ease.linear]);
      // Segment 0 at local t 0.5, shaped by Ease.snappy.
      expect(
        eased.keyframeAt(0.25).opacity,
        closeTo(Ease.snappy.transform(0.5), 1e-12),
      );
      // Segment 1 stays linear.
      expect(eased.keyframeAt(0.75).opacity, closeTo(0.75, 1e-12));
    });

    test('easings length must be stops.length - 1', () {
      expect(
        () => MultiKeyframeEffect(stops, easings: List.of([Ease.linear])).keyframeAt(0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('construction', () {
    test('fewer than two stops asserts', () {
      expect(
        () => MultiKeyframeEffect(List.of(const [Keyframe(opacity: 0)])).keyframeAt(0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('carries the raw stop Times for the pipeline to resolve (D17)', () {
      const timed = MultiKeyframeEffect(
        stops,
        at: [Time.zero, Time.frames(8), Time.frames(20)],
      );
      expect(timed.at, const [Time.zero, Time.frames(8), Time.frames(20)]);
      expect(effect.at, isNull);
    });

    test('a stop-Time count mismatch asserts', () {
      expect(
        () => MultiKeyframeEffect(stops, at: List.of(const [Time.zero])).keyframeAt(0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('build', () {
    test('applies the interpolated keyframe to the child', () {
      // The applier's outer fade is the FadeBox primitive (D16-P6).
      final built = effect.build(const SizedBox(), 0.25);
      expect(built, isA<FadeBox>());
      expect((built as FadeBox).opacity, closeTo(0.5, 1e-12));
    });
  });
}
