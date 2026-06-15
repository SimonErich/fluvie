// Epic 9.1 acceptance goldens: each pixel post-effect over a font-free
// ColoredBox subject at a representative frame, plus the §27.6 ordering golden
// proving a transform and a pixel effect compose to the identical image
// regardless of their order in the `.animate()` list. Subjects stay font-free
// (D20); a teal corner marker shows where transforms move the square.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/repeat.dart';

import 'helpers/golden_frame.dart';

const _purple = Color(0xFF6C5CE7);
const _teal = Color(0xFF00B894);

/// A bright square with a teal corner so a chromatic split and a transform
/// both read clearly against the overlay.
Widget _square() => const SizedBox(
  width: 64,
  height: 64,
  child: ColoredBox(
    color: _purple,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 20, height: 20, child: ColoredBox(color: _teal)),
    ),
  ),
);

/// Mounts [animations] on the square at full strength across the window so the
/// pixel overlay is fully present at the probed frame.
Widget _withFx(List<Animation> animations) => Center(child: _square().animate(animations));

/// A pixel effect held at full strength for the whole window: a `during`
/// custom animation never fades, so the overlay reads the same every frame.
Animation _hold(Animation pixel) => Animation.custom(
  pixel.effect,
  phase: AnimationPhase.during,
  repeat: const Repeat.forever(),
);

Future<void> main() async {
  await goldenMotionFrames(
    description: 'grain: seeded monochrome speckle over the square',
    fileName: 'effect_grain',
    frames: const [30],
    subject: () => _withFx([_hold(Animation.grain(0.5))]),
  );

  await goldenMotionFrames(
    description: 'vignette: radial edge darkening',
    fileName: 'effect_vignette',
    frames: const [30],
    subject: () => _withFx([_hold(Animation.vignette(0.7))]),
  );

  await goldenMotionFrames(
    description: 'scanlines: thin dark horizontal lines',
    fileName: 'effect_scanlines',
    frames: const [30],
    subject: () => _withFx([_hold(Animation.scanlines())]),
  );

  await goldenMotionFrames(
    description: 'chromatic: red/blue channel split fringing the edges',
    fileName: 'effect_chromatic',
    frames: const [30],
    subject: () => _withFx([_hold(Animation.chromatic(3))]),
  );

  await goldenMotionFrames(
    description: 'bloom: soft glow bleeding out of the bright square',
    fileName: 'effect_bloom',
    frames: const [30],
    subject: () => _withFx([_hold(Animation.bloom(0.8))]),
  );

  // glitchIn resolves to natural at progress 1, so probe it mid-enter where
  // the slices and split are visible.
  await goldenMotionFrames(
    description: 'glitchIn: sliced jitter plus chromatic split, mid-enter',
    fileName: 'effect_glitch_in',
    frames: const [6],
    subject: () => _withFx([Animation.glitchIn()]),
  );

  // The §27.6 ordering acceptance: a transform and a pixel effect produce the
  // identical frame whichever order they sit in the list (the pipeline always
  // applies transforms inner, pixels outer). The two panels must match.
  await goldenMotionVariants(
    description: 'ordering: [slideFade, grain] and [grain, slideFade] are identical (§27.6)',
    fileName: 'effect_ordering_invariant',
    frame: 8,
    variants: [
      ('transform then pixel', () => _withFx([Animation.slideFade(), _hold(Animation.grain(0.4))])),
      ('pixel then transform', () => _withFx([_hold(Animation.grain(0.4)), Animation.slideFade()])),
    ],
  );
}
