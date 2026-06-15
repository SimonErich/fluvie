import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/effect_kind.dart';

import 'fakes/fake_pixel_effect.dart';

/// The §6 custom-effect example, verbatim: a plain `implements
/// AnimationEffect` with no extra members must compile against the contract.
final class Shear implements AnimationEffect {
  const Shear({this.maxSkew = 0.3});
  final double maxSkew;
  @override
  Widget build(Widget child, double progress) =>
      Transform(transform: Matrix4.skewX((1 - progress) * maxSkew), child: child);
}

void main() {
  group('AnimationEffect contract', () {
    test('the §6 Shear example compiles and builds', () {
      const effect = Shear();
      final built = effect.build(const SizedBox(), 0.5);
      expect(built, isA<Transform>());
    });
  });

  group('effectKindOf', () {
    test('a plain AnimationEffect classifies as transform', () {
      expect(effectKindOf(const Shear()), EffectKind.transform);
    });

    test('a PixelAnimationEffect classifies as pixel', () {
      expect(effectKindOf(const FakePixelEffect()), EffectKind.pixel);
    });

    test('classification is type-driven, not instance state', () {
      // Two instances with different state classify identically; the marker
      // interface alone decides the kind.
      expect(effectKindOf(const Shear(maxSkew: 0.9)), EffectKind.transform);
      expect(
        effectKindOf(const FakePixelEffect(color: Color(0xFF000000))),
        EffectKind.pixel,
      );
    });

    test('EffectKind has exactly the two spec classes', () {
      expect(EffectKind.values, [EffectKind.transform, EffectKind.pixel]);
    });
  });
}
