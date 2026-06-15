// WI-22 (D-BeatWiring): a beat-pop golden. A Video with a Trigger.beat fade,
// mounted under a BeatGridScope carrying a committed grid fixture, resolves the
// fade to the grid's beat frame and paints it. The three probed frames straddle
// the beat (the box is invisible before it, half-faded on it, fully shown
// after), proving the shell-mounted grid drives the resolution. Subjects stay
// font-free (D20).
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/rendering/capture/beat_grid_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// The committed grid fixture: a single beat at frame 15. The fade is a
/// 10-frame linear window, so it resolves to 15..25.
class _BeatAt15 implements BeatGrid {
  const _BeatAt15();
  @override
  int? firstBeatAtOrAfter(int frame, {int every = 1}) => frame <= 15 ? 15 : null;
}

/// A red square that fades in on the beat — font-free, so the golden carries no
/// font variance.
Widget _beatBox() =>
    const Center(
      child: ColoredBox(
        color: Color(0xFFE74C3C),
        child: SizedBox(width: 60, height: 60),
      ),
    ).animate([
      Animation.fadeIn(
        at: const Trigger.beat(),
        duration: const Time.frames(10),
        ease: Ease.linear,
      ),
    ]);

/// One scenario per probed frame: a full Video under a BeatGridScope, clocked at
/// [frame]. The post-frame resolve runs during the pump-and-settle, so the fade
/// is placed at the grid's beat before the snapshot.
GoldenTestScenario _scenario(int frame) => GoldenTestScenario(
  name: 'frame $frame',
  child: SizedBox(
    width: 120,
    height: 120,
    child: RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(
        controller: RenderController(initialFrame: frame),
        child: BeatGridScope(
          defaultBeatGrid: const _BeatAt15(),
          trackBeatGrids: const <Anchor, BeatGrid>{},
          child: Video(
            width: 120,
            height: 120,
            scenes: [
              Scene(duration: const Time.frames(40), children: [_beatBox()]),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'beatPop: a fade fires on the grid beat (15) — hidden at 10, lit at 25',
    fileName: 'beat_pop',
    builder: () => GoldenTestGroup(
      children: [_scenario(10), _scenario(20), _scenario(30)],
    ),
  );
}
