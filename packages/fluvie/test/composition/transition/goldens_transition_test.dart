// Epic 7.1 acceptance goldens (D19): the TransitionCompositor mounted
// directly under RenderControllerScope + VideoScope with two minimal scene
// shells mirroring `_sceneShell` — the engine proven before the public
// wiring (Epic 7.2 re-pins these through `Video`).
//
// Two 60-frame scenes at 30 fps with a 20-frame transition (overlap):
// starts [0, 40], blend window [40, 60). The mid goldens sample frame 49
// (p = 0.5); the boundary pair samples the solo frames bracketing the
// window (39 and 60). Scenes carry an off-center marker square so motion
// (wipe front, zoom scale, slide push) is visible against the solid fills;
// everything stays font-free (D20).
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/transition_compositor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _red = Color(0xFFE74C3C);
const _blue = Color(0xFF2980B9);

/// One scene's fill plus an off-center marker square, so wipes, zooms, and
/// slides read as motion instead of a flat color change.
Widget _scene(Color fill, Color marker, Alignment markerAt) => ColoredBox(
  color: fill,
  child: Align(
    alignment: markerAt,
    child: SizedBox(width: 48, height: 48, child: ColoredBox(color: marker)),
  ),
);

/// The D19 harness, mirroring `_sceneShell`: frame clock → root scope →
/// compositor over two SceneScope shells at the resolved offsets.
Widget _harness({required Transition transition, required int frame}) {
  final transitions = [transition];
  final offsets = resolveSceneOffsets(
    fps: 30,
    durations: [60.frames, 60.frames],
    transitions: transitions,
  );
  Widget shell(int index, Widget content) => SceneScope(
    start: Time.frames(offsets.startFrames[index]),
    duration: Time.frames(offsets.durationFrames[index]),
    child: content,
  );
  return SizedBox(
    width: 160,
    height: 284,
    child: RenderControllerScope(
      controller: RenderController(initialFrame: frame),
      child: VideoScope(
        fps: 30,
        duration: Time.frames(offsets.totalFrames),
        child: TransitionCompositor(
          offsets: offsets,
          transitions: transitions,
          sceneShells: [
            shell(0, _scene(_red, const Color(0xFFFFFFFF), const Alignment(-0.6, -0.6))),
            shell(1, _scene(_blue, const Color(0xFF111111), const Alignment(0.6, 0.6))),
          ],
        ),
      ),
    ),
  );
}

GoldenTestGroup _group(String name, Transition transition, int frame) => GoldenTestGroup(
  children: [
    GoldenTestScenario(
      name: name,
      child: _harness(transition: transition, frame: frame),
    ),
  ],
);

Future<void> main() async {
  await goldenTest(
    'crossFade at the window midpoint: incoming at half opacity over the outgoing',
    fileName: 'transition_crossfade_mid',
    builder: () => _group('frame 49 (p = 0.5)', Transition.crossFade(20.frames), 49),
  );

  await goldenTest(
    'wipe toward Edge.right at the midpoint: the incoming covers the left half',
    fileName: 'transition_wipe_mid',
    builder: () => _group('frame 49 (p = 0.5)', Transition.wipe(20.frames), 49),
  );

  await goldenTest(
    'zoom at the midpoint: the outgoing on top, scaled 1.5, at half opacity',
    fileName: 'transition_zoom_mid',
    builder: () => _group('frame 49 (p = 0.5)', Transition.zoom(20.frames), 49),
  );

  await goldenTest(
    'slide from Edge.right at the midpoint: a push caught half-way',
    fileName: 'transition_slide_mid',
    builder: () => _group('frame 49 (p = 0.5)', Transition.slide(20.frames), 49),
  );

  await goldenTest(
    'the frame before the blend window is the pure outgoing scene',
    fileName: 'transition_boundary_before',
    builder: () => _group('frame 39 (solo)', Transition.crossFade(20.frames), 39),
  );

  await goldenTest(
    'the frame after the blend window is the pure incoming scene',
    fileName: 'transition_boundary_after',
    builder: () => _group('frame 60 (solo)', Transition.crossFade(20.frames), 60),
  );
}
