// Epic 5.3 acceptance goldens: every enter/exit preset rendered through the
// real `.animate()` path, pinning the D18 micro-defaults frame by frame.
//
// Tween presets run an explicit 20-frame linear tween and snapshot 0/50/100%
// of their span (exits are end-anchored, so their span sits at the window
// end and the 100% frame is sampled one frame early — the window's last
// visible frame). Spring presets snapshot frames 0/8/16 plus the settle
// frame computed in-test from SpringSolver (D20).
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/spring_solver.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/wipe_shape.dart';

import 'helpers/golden_frame.dart';

const _purple = Color(0xFF6C5CE7);
const _tween = Time.frames(20);

Widget _square() => const SizedBox(width: 48, height: 48, child: ColoredBox(color: _purple));

Widget _animated(Animation animation) => Center(child: _square().animate([animation]));

Future<void> main() async {
  await goldenMotionFrames(
    description: 'fadeIn: transparent at 0, half at 10, natural at 20',
    fileName: 'animation_fade_in',
    frames: const [0, 10, 20],
    subject: () => _animated(Animation.fadeIn(duration: _tween, ease: Ease.linear)),
  );

  await goldenMotionFrames(
    description: 'fadeOut: end-anchored — natural at 40, half at 50, nearly gone at 59',
    fileName: 'animation_fade_out',
    frames: const [40, 50, 59],
    subject: () => _animated(Animation.fadeOut(duration: _tween, ease: Ease.linear)),
  );

  await goldenMotionVariants(
    description: 'slideIn from each edge, caught half-way (frame 10 of 20)',
    fileName: 'animation_slide_in_edges',
    frame: 10,
    variants: [
      for (final edge in Edge.values)
        (
          'from ${edge.name}',
          () => _animated(Animation.slideIn(from: edge, duration: _tween, ease: Ease.linear)),
        ),
    ],
  );

  await goldenMotionFrames(
    description: 'slideFade: rises from below while fading in',
    fileName: 'animation_slide_fade',
    frames: const [0, 10, 20],
    subject: () => _animated(Animation.slideFade(duration: _tween, ease: Ease.linear)),
  );

  await goldenMotionFrames(
    description: 'blurIn: sigma 12 → 6 → sharp (blur-only, D18)',
    fileName: 'animation_blur_in',
    frames: const [0, 10, 20],
    subject: () => _animated(Animation.blurIn(duration: _tween, ease: Ease.linear)),
  );

  await goldenMotionFrames(
    description: 'blurOut: end-anchored — sharp at 40, sigma 6 at 50, sigma ~11.4 at 59',
    fileName: 'animation_blur_out',
    frames: const [40, 50, 59],
    subject: () => _animated(Animation.blurOut(duration: _tween, ease: Ease.linear)),
  );

  await goldenMotionVariants(
    description: 'maskWipe shapes, caught half-revealed (frame 10 of 20)',
    fileName: 'animation_mask_wipe',
    frame: 10,
    variants: [
      for (final shape in WipeShape.values)
        (
          shape.name,
          () => _animated(Animation.maskWipe(shape: shape, duration: _tween, ease: Ease.linear)),
        ),
    ],
  );

  // Spring presets: the span is the settle time, computed exactly as the
  // resolver does (API_SPEC §27.4) — at the settle frame progress is forced
  // to exactly 1.0 (D6), so the last scenario shows the natural state.
  final popSettle = SpringSolver(Animation.pop().spring!).settleFrames(30);
  await goldenMotionFrames(
    description: 'pop: scale 0 → overshoot past natural → settled at frame $popSettle',
    fileName: 'animation_pop',
    frames: [0, 8, 16, popSettle],
    subject: () => _animated(Animation.pop()),
  );

  final scaleInSettle = SpringSolver(Animation.scaleIn().spring!).settleFrames(30);
  await goldenMotionFrames(
    description: 'scaleIn: scale 0.85 → Spring.snappy → settled at frame $scaleInSettle',
    fileName: 'animation_scale_in',
    frames: [0, 8, 16, scaleInSettle],
    subject: () => _animated(Animation.scaleIn()),
  );
}
