// Epic 6.3 background goldens (WI-24): every renderable Background variant on
// a fixed 160×284 canvas (a 9:16 story in miniature), plus the gradient shift
// caught at the start, middle, and end of a 20-frame linear run. All subjects
// are font-free, and the noise/vhs textures are seeded (D12), so the pixels
// carry zero variance.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';

import '../animation/helpers/golden_frame.dart';

const _red = Color(0xFFE74C3C);
const _green = Color(0xFF2ECC71);
const _blue = Color(0xFF3498DB);
const _white = Color(0xFFFFFFFF);
const _ink = Color(0xFF101020);
const _canvas = Size(160, 284);

/// One static Background variant, one golden file, one scenario.
Future<void> _backgroundGolden({
  required String description,
  required String fileName,
  required Background Function() subject,
}) => goldenMotionVariants(
  description: description,
  fileName: fileName,
  frame: 0,
  size: _canvas,
  variants: [(fileName.replaceFirst('background_', ''), subject)],
);

Future<void> main() async {
  await _backgroundGolden(
    description: 'Background.color: one flat ink fill edge to edge',
    fileName: 'background_color',
    subject: () => Background.color(_ink),
  );

  await _backgroundGolden(
    description: 'Background.gradient: red → green along the default top-left diagonal',
    fileName: 'background_gradient',
    subject: () => Background.gradient(const [_red, _green]),
  );

  await _backgroundGolden(
    description: 'Background.radial: white core fading to blue at the edges',
    fileName: 'background_radial',
    subject: () => Background.radial(const [_white, _blue]),
  );

  await _backgroundGolden(
    description: 'Background.noise: seeded grayscale cell noise (D12)',
    fileName: 'background_noise',
    subject: () => Background.noise(scale: 2),
  );

  await _backgroundGolden(
    description: 'Background.vhs: seeded scanlines over static bands (D12)',
    fileName: 'background_vhs',
    subject: Background.vhs,
  );

  await goldenMotionFrames(
    description: 'gradientShift: base at 0, half-lerped at 10, fully shifted at 20',
    fileName: 'background_gradient_shift',
    frames: const [0, 10, 20],
    size: _canvas,
    subject: () => Background.gradient(const [_red, _green]).animate([
      Animation.gradientShift(
        to: const [_blue, _green],
        duration: const Time.frames(20),
        ease: Ease.linear,
      ),
    ]),
  );
}
