// Epic 6.4 layout goldens (WI-30): the §14 Box grow-in rule at three frames,
// the four D15 Frame styles side by side, and a registrar-resolved stagger
// across a Stack inside a real Video (the D1 pipeline end to end). All
// subjects are font-free, so the pixels carry zero variance.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/frame.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

import '../animation/helpers/golden_frame.dart';

const _ink = Color(0xFF101020);
const _white = Color(0xFFFFFFFF);
const _red = Color(0xFFE74C3C);
const _green = Color(0xFF2ECC71);
const _blue = Color(0xFF3498DB);

/// Centers [child] over a flat ink backdrop so light subjects stay visible.
Widget _onInk(Widget child) => Stack(
  alignment: Alignment.center,
  fit: StackFit.expand,
  children: [
    const ColoredBox(color: _ink),
    Center(child: child),
  ],
);

/// One registrar-resolved scenario: a real [Video] under its own frame clock,
/// resolved by the D1 post-frame pass before Alchemist captures (the default
/// pump-and-settle covers the collect → resolve → rebuild sequence).
GoldenTestScenario _videoScenario({
  required String name,
  required int frame,
  required Video video,
}) => GoldenTestScenario(
  name: name,
  child: SizedBox(
    width: 160,
    height: 284,
    child: RenderControllerScope(
      controller: RenderController(initialFrame: frame),
      child: video,
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'Box grow-in: the §14 rule at scaleX 0, 0.5, and 1',
    fileName: 'composition_box_grow',
    builder: () => motionFrameGroup(
      frames: const [0, 10, 20],
      size: const Size(160, 120),
      subject: () => _onInk(
        const Box(color: _white, size: Size(0.5, 0.05)).animate([
          Animation.from(
            const Keyframe(scaleX: 0),
            duration: const Time.frames(20),
            ease: Ease.linear,
          ),
        ]),
      ),
    ),
  );

  await goldenTest(
    'Frame: the four D15 styles around the same content',
    fileName: 'composition_frames',
    builder: () => motionVariantsGroup(
      frame: 0,
      size: const Size(120, 130),
      variants: [
        for (final (name, frame) in <(String, Widget Function(Widget))>[
          ('none', (child) => Frame.none(child: child)),
          ('rounded', (child) => Frame.rounded(child: child)),
          ('card', (child) => Frame.card(child: child)),
          ('polaroid', (child) => Frame.polaroid(child: child)),
        ])
          (
            name,
            () => _onInk(
              frame(const SizedBox(width: 64, height: 44, child: ColoredBox(color: _blue))),
            ),
          ),
      ],
    ),
  );

  await goldenTest(
    'Stack stagger inside Video: child 0 mid-flight at frame 4, 1 and 2 waiting',
    fileName: 'composition_stack_stagger',
    builder: () => GoldenTestGroup(
      children: [
        _videoScenario(
          name: 'frame 4',
          frame: 4,
          video: Video(
            width: 160,
            height: 284,
            scenes: [
              Scene(
                duration: 30.frames,
                children: [
                  Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      for (final (i, color) in const [_red, _green, _blue].indexed)
                        Positioned(
                          left: 56,
                          top: 24 + i * 88.0,
                          width: 48,
                          height: 48,
                          child: ColoredBox(color: color),
                        ),
                    ],
                  ).animate([
                    Animation.slideFadeIn(
                      duration: const Time.frames(8),
                      ease: Ease.linear,
                      stagger: const Stagger.each(Time.frames(6)),
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
