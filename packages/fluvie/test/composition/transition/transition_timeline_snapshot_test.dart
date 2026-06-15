import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/timeline/debug_timeline.dart';

Animation _fade(int frames) => Animation.from(
  const Keyframe(opacity: 0),
  duration: Time.frames(frames),
  ease: Ease.linear,
);

/// One anchored fade per scene, so every scene contributes a timeline row at
/// its (transition-adjusted) absolute start frame.
Scene _scene(String label, {Transition? enter, Transition? exit}) => Scene(
  duration: 2.seconds,
  enter: enter,
  exit: exit,
  children: [
    SizedBox(key: Key(label), width: 10, height: 10).animate([_fade(30)], anchor: Anchor(label)),
  ],
);

Widget _harness(
  Video video, {
  required RenderController controller,
  required TimelineProbe probe,
}) => RenderModeContext(
  mode: RenderMode.capture,
  child: RenderControllerScope(
    controller: controller,
    child: TimelineProbeScope(probe: probe, child: video),
  ),
);

void main() {
  group('Transition timeline snapshots (WI-11, D3/D14)', () {
    testWidgets('the concept mixed timeline: wipe boundary 0 sequential, crossFade 1 overlapped', (
      tester,
    ) async {
      final probe = TimelineProbe();
      final video = Video(
        width: 320,
        height: 240,
        transition: Transition.crossFade(0.5.seconds), // overlap defaults true
        scenes: [
          _scene('a'),
          // scene 2 (index 1) enters across boundary 0 with a sequential wipe.
          _scene('b', enter: Transition.wipe(0.4.seconds, overlap: false)),
          _scene('c'),
        ],
      );
      await tester.pumpWidget(_harness(video, controller: RenderController(), probe: probe));
      await tester.pump();

      // boundary 0: wipe sequential -> no shift; boundary 1: crossFade overlap
      // by 15 -> scene 3 starts 15 early. (D2/D3 math.)
      expect(video.sceneStartFrames, [0, 60, 105]);
      expect(video.totalFrames, 165);

      final timeline = probe.value!;
      expect(timeline.warnings, isEmpty);
      expect(timeline.totalFrames, 165);
      expect(debugTimeline(timeline), _kMixedTimeline);
    });

    testWidgets('flipping both boundaries: crossFade boundary 0 overlap, wipe 1 sequential', (
      tester,
    ) async {
      final probe = TimelineProbe();
      final video = Video(
        width: 320,
        height: 240,
        transition: Transition.wipe(0.4.seconds, overlap: false),
        scenes: [
          _scene('a'),
          // scene 2 enters across boundary 0 with an overlapping crossFade.
          _scene('b', enter: Transition.crossFade(0.5.seconds)),
          _scene('c'),
        ],
      );
      await tester.pumpWidget(_harness(video, controller: RenderController(), probe: probe));
      await tester.pump();

      // boundary 0: crossFade overlap 15 -> scene 2 starts at 45; boundary 1:
      // wipe sequential -> scene 3 at 45 + 60 = 105.
      expect(video.sceneStartFrames, [0, 45, 105]);
      expect(video.totalFrames, 165);
      expect(probe.value!.warnings, isEmpty);
      expect(debugTimeline(probe.value!), _kFlippedTimeline);
    });
  });
}

/// Boundary 0 wipe sequential (no shift), boundary 1 crossFade overlapped by
/// 15: scene rows start at 0, 60, 105 (decision D3).
const _kMixedTimeline =
    'owner  | label | phase | start | end | frames\n'
    '-------+-------+-------+-------+-----+-------\n'
    's0e0:a | -     | enter |     0 |  30 |     30\n'
    's1e0:b | -     | enter |    60 |  90 |     30\n'
    's2e0:c | -     | enter |   105 | 135 |     30\n'
    'total: 165 frames @ 30 fps\n';

/// Boundary 0 crossFade overlapped by 15 (scene 2 at 45), boundary 1 wipe
/// sequential (scene 3 at 105) — the same total, the other distribution.
const _kFlippedTimeline =
    'owner  | label | phase | start | end | frames\n'
    '-------+-------+-------+-------+-----+-------\n'
    's0e0:a | -     | enter |     0 |  30 |     30\n'
    's1e0:b | -     | enter |    45 |  75 |     30\n'
    's2e0:c | -     | enter |   105 | 135 |     30\n'
    'total: 165 frames @ 30 fps\n';
