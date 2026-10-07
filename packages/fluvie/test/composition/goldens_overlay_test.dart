// An overlay held across a whole video, boundaries and blends included. Three
// scenes with a crossFade between each pair: the scene squares change and the
// overlay badge does not, because it is one element that was never in a scene
// to be swapped out of. Subjects stay font-free (D20).
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// One scene's subject: a filled square, a different colour per scene, so a
/// boundary crossing is unmistakable.
Widget _scene(Color color) => Center(
  child: ColoredBox(
    color: color,
    child: const SizedBox(width: 70, height: 70),
  ),
);

/// The overlay: a small badge parked in the corner, outside every scene.
Widget _badge() => const Align(
  alignment: Alignment.topRight,
  child: Padding(
    padding: EdgeInsets.all(8),
    child: ColoredBox(
      color: Color(0xFFFFB224),
      child: SizedBox(width: 24, height: 24),
    ),
  ),
);

/// A full video clocked at [frame]: three 30-frame scenes with a 10-frame
/// crossFade at each boundary, and one overlay for the whole thing.
GoldenTestScenario _scenario(int frame) => GoldenTestScenario(
  name: 'frame $frame',
  child: SizedBox(
    width: 120,
    height: 120,
    child: RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(
        controller: RenderController(initialFrame: frame),
        child: Video(
          width: 120,
          height: 120,
          transition: const Transition.crossFade(Time.frames(10)),
          overlays: [_badge()],
          scenes: [
            Scene(
              duration: const Time.frames(30),
              children: [_scene(const Color(0xFF2ECC8F))],
            ),
            Scene(
              duration: const Time.frames(30),
              children: [_scene(const Color(0xFF0090FF))],
            ),
            Scene(
              duration: const Time.frames(30),
              children: [_scene(const Color(0xFFE5484D))],
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'an overlay holds across every scene boundary as one element',
    fileName: 'overlay_held',
    builder: () => GoldenTestGroup(
      // Mid scene 1, inside the first blend, mid scene 2, inside the second
      // blend, and late in scene 3 (the video is 70 frames after the two
      // overlaps): the square changes at every step, the badge never moves
      // and never blinks.
      children: [_scenario(15), _scenario(28), _scenario(45), _scenario(58), _scenario(65)],
    ),
  );
}
