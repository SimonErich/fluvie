// Epic 9.2 acceptance goldens: the seeded particle fields (confetti, snow) at a
// representative mid-scene frame, and a parallax drift showing the depth-scaled
// offset, all over font-free subjects (D20). The mask golden is confirmed
// separately in goldens_presets_test.dart (animation_mask_wipe) — verify-only
// per WI-10, no new mask golden needed here.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/core/time.dart';

import 'helpers/golden_frame.dart';

const _black = Color(0xFF000000);
const _teal = Color(0xFF00B894);

/// A black field with a teal corner so a parallax translation reads clearly.
Widget _field() => const SizedBox(
  width: 100,
  height: 100,
  child: ColoredBox(
    color: _black,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 24, height: 24, child: ColoredBox(color: _teal)),
    ),
  ),
);

/// Drives an effect `during` the whole 60-frame scene at linear progress so the
/// field/drift sits at a known position at the probed frame.
Animation _during(Animation a) => Animation.custom(
  a.effect,
  phase: AnimationPhase.during,
  duration: const Time.frames(60),
  ease: Ease.linear,
);

Widget _withFx(List<Animation> animations) => Center(child: _field().animate(animations));

Future<void> main() async {
  await goldenMotionFrames(
    description: 'particles confetti: a seeded tumbling field, mid-scene',
    fileName: 'particles_confetti_mid',
    frames: const [30],
    subject: () => _withFx([_during(Animation.particles(const Particles.confetti(seed: 'win')))]),
  );

  await goldenMotionFrames(
    description: 'particles snow: a seeded soft snowfall, mid-scene',
    fileName: 'particles_snow_mid',
    frames: const [30],
    subject: () => _withFx([_during(Animation.particles(const Particles.snow(seed: 'flurry')))]),
  );

  await goldenMotionFrames(
    description: 'particles sparkle: a seeded twinkling glint field, mid-scene',
    fileName: 'particles_sparkle_mid',
    frames: const [30],
    subject: () => _withFx([_during(Animation.particles(const Particles.sparkle(seed: 'glint')))]),
  );

  // Parallax reads the scene clock itself, so probe two depths at the same
  // frame: the deeper layer's teal corner sits lower than the shallow one.
  await goldenMotionVariants(
    description: 'parallax: a far (0.2) and a near (0.6) layer drift at frame 45',
    fileName: 'parallax_depths',
    frame: 45,
    variants: [
      ('far depth 0.2', () => _withFx([Animation.parallax()])),
      ('near depth 0.6', () => _withFx([Animation.parallax(depth: 0.6)])),
    ],
  );
}
