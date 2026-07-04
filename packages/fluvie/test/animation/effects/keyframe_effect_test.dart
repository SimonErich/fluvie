import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effects/keyframe_animation_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_effect.dart';
import 'package:fluvie/src/core/keyframe.dart';

void main() {
  group('KeyframeEffect.keyframeAt', () {
    const from = Keyframe(opacity: 0, y: 1);
    const effect = KeyframeEffect(from: from, to: Keyframe.natural);

    test('is a KeyframeAnimationEffect', () {
      expect(effect, isA<KeyframeAnimationEffect>());
    });

    test('matches Keyframe.lerp at 0, 0.5, and 1', () {
      for (final t in [0.0, 0.5, 1.0]) {
        expect(effect.keyframeAt(t), Keyframe.lerp(from, Keyframe.natural, t));
      }
    });

    test('progress 0.5 lerps each named field toward its identity', () {
      final mid = effect.keyframeAt(0.5);
      expect(mid.opacity, 0.5);
      expect(mid.y, 0.5);
    });

    test('unnamed fields pass through as null (stay natural)', () {
      final mid = effect.keyframeAt(0.5);
      expect(mid.scale, isNull);
      expect(mid.rotation, isNull);
      expect(mid.blur, isNull);
      expect(mid.x, isNull);
    });

    test('overshoot p > 1 extrapolates (spring support)', () {
      const reveal = KeyframeEffect(from: Keyframe(scale: 0), to: Keyframe.natural);
      final over = reveal.keyframeAt(1.1);
      expect(over.scale, closeTo(1.1, 1e-12));
    });

    test('color lerps along the data path (D9)', () {
      const colorize = KeyframeEffect(
        from: Keyframe(color: Color(0xFF000000)),
        to: Keyframe(color: Color(0xFFFFFFFF)),
      );
      final mid = colorize.keyframeAt(0.5);
      expect(
        mid.color,
        Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5),
      );
    });
  });
}
