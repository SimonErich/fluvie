// Epic 5.2 acceptance goldens: real motion through the full
// `.animate()`/`.show()` path, frame by frame (decision D20).
//
// LIMITATION: cross-element `after`/`whenStarts` goldens need
// composition-level resolution and land with Phase 6 Video/Scene;
// `previous` below is the window-local end-to-end trigger proof.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';

import 'helpers/golden_frame.dart';

const _purple = Color(0xFF6C5CE7);
const _teal = Color(0xFF00B894);

Widget _square(Color color) => SizedBox(width: 48, height: 48, child: ColoredBox(color: color));

Future<void> main() async {
  await goldenMotionFrames(
    description: 'two keyframe animations compose into one stack — opacity and slide move together',
    fileName: 'animation_compose_fade_slide',
    frames: const [0, 10, 20],
    subject: () => Center(
      child: _square(_purple).animate([
        Animation.from(
          const Keyframe(opacity: 0),
          duration: const Time.frames(20),
          ease: Ease.linear,
        ),
        Animation.from(
          const Keyframe(y: 0.5),
          duration: const Time.frames(20),
          ease: Ease.linear,
        ),
      ]),
    ),
  );

  await goldenMotionFrames(
    description: 'show(from, to): hidden before/after the window, layout slot held throughout',
    fileName: 'animation_show_window',
    frames: const [5, 20, 45],
    subject: () => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _square(_purple).show(from: 10.frames, to: 40.frames),
            _square(_teal),
          ],
        ),
      ),
    ),
  );

  await goldenMotionFrames(
    description: 'Trigger.previous chains a slide after a fade within one element',
    fileName: 'animation_previous_chain',
    frames: const [10, 20, 30, 40],
    subject: () => Center(
      child: _square(_purple).animate([
        Animation.from(
          const Keyframe(opacity: 0),
          duration: const Time.frames(20),
          ease: Ease.linear,
        ),
        Animation.fromTo(
          Keyframe.natural,
          const Keyframe(x: 0.5),
          duration: const Time.frames(20),
          ease: Ease.linear,
          at: Trigger.previous,
        ),
      ]),
    ),
  );
}
