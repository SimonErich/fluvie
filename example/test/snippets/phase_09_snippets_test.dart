// The Phase 9 doc snippets compile and build (WI-23): the shaders-and-effects
// page pulls these via code-excerpt markers, so a failing build here means a
// doc would ship dead code.

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/phase_09_snippets.dart';

void main() {
  test('the particles and shader snippets build a widget', () {
    expect(confettiCaption(), isA<Widget>());
    expect(rippleLogo(), isA<Widget>());
  });

  test('the seeded-float snippet builds an animation', () {
    expect(seededFloat(), isA<Animation>());
  });

  test('the custom-effect snippet is a pixel-classified animation', () {
    final animation = scanlineSweepText();
    expect(animation, isA<Widget>());
    // The custom effect opts into the pixel class (API_SPEC §27.6).
    expect(const ScanlineSweep(), isA<PixelAnimationEffect>());
    expect(effectKindOf(const ScanlineSweep()), EffectKind.pixel);
  });
}
