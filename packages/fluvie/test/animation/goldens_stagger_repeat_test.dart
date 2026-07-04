// Epic 5.4 acceptance goldens: stagger distribution across a multi-child
// target and repeat+yoyo cycling, frame by frame (decisions D12/D13/D19/D20).
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/stagger_origin.dart';
import 'package:fluvie/src/core/time.dart';

import 'helpers/golden_frame.dart';

const _purple = Color(0xFF6C5CE7);
const _teal = Color(0xFF00B894);
const _orange = Color(0xFFE17055);
const _yellow = Color(0xFFFDCB6E);
const _blue = Color(0xFF0984E3);

Widget _square(Color color, {double size = 24}) => SizedBox(
  width: size,
  height: size,
  child: ColoredBox(color: color),
);

Future<void> main() async {
  await goldenMotionFrames(
    description:
        'Stagger.each(6 frames) on a Column of 3: per-child offsets visibly cascade bottom-up',
    fileName: 'animation_stagger_column',
    frames: const [0, 6, 12, 26],
    subject: () => Center(
      child:
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [_square(_purple), _square(_teal), _square(_orange)],
          ).animate([
            Animation.slideFadeIn(
              stagger: const Stagger.each(Time.frames(6)),
              duration: const Time.frames(20),
              ease: Ease.linear,
            ),
          ]),
    ),
  );

  await goldenMotionFrames(
    description:
        'Stagger.from(center) on 5 squares at mid-tween: the middle leads, lower index wins ties',
    fileName: 'animation_stagger_center_origin',
    frames: const [8],
    subject: () => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child:
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: [
                _square(_purple, size: 18),
                _square(_teal, size: 18),
                _square(_orange, size: 18),
                _square(_yellow, size: 18),
                _square(_blue, size: 18),
              ],
            ).animate([
              Animation.slideFadeIn(
                stagger: const Stagger.from(StaggerOrigin.center),
                duration: const Time.frames(20),
                ease: Ease.linear,
              ),
            ]),
      ),
    ),
  );

  await goldenMotionFrames(
    description:
        'pulse over a 24-frame period: scale runs up-down-up across one yoyo pair (repeat+yoyo)',
    fileName: 'animation_pulse_yoyo',
    frames: const [0, 6, 12, 18, 24],
    subject: () => Center(
      child: _square(_purple, size: 48).animate([
        Animation.pulse(min: 0.5, max: 1.5, period: const Time.frames(24)),
      ]),
    ),
  );
}
