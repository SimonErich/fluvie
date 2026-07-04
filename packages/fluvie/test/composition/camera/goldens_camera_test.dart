// Epic 7.4 acceptance goldens (concept 7.4) plus the ordering guardrail. Each
// mounts a full Video under a static RenderControllerScope so the compositor's
// frame reader, the per-scene CameraLayer, and (for the hero case) the morph
// overlay all run from the one frame clock — the determinism contract.
//
// All scenes are 2s @ 30 fps (60 frames). A camera with the default over =
// 1.0.relative runs the whole scene, so frame 30 is the midpoint (q = 0.5).
// Everything stays font-free (D20): Boxes and ColoredBoxes only.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/camera/camera.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

const _canvas = Size(160, 284);
const _bg = Color(0xFF1B2838);
const _tile = Color(0xFFE67E22);
const _scene2 = Color(0xFF8E44AD);
const _logo = Color(0xFFF1C40F);

// A column of three tile rows so a scene-wide scale and the focal point both
// read clearly under the camera (const so each golden mounts deterministically).
Widget _tileRow() => const Expanded(
  child: Padding(
    padding: EdgeInsets.all(6),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(6),
            child: Box(color: _tile),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(6),
            child: Box(color: _tile),
          ),
        ),
      ],
    ),
  ),
);

Widget _tiles() => Column(children: [_tileRow(), _tileRow(), _tileRow()]);

// A single Video scene with [camera] over a grid of tiles.
Video _cameraVideo(Camera camera) => Video(
  width: 160,
  height: 284,
  scenes: [
    Scene(
      duration: 2.seconds,
      background: Background.color(_bg),
      camera: camera,
      children: [_tiles()],
    ),
  ],
);

// A scene whose Box scales itself in (element transform) inside a pushing
// camera (scene transform) — at a frame where both are mid-flight, this pins
// the composition order camera ∘ element.
Video _orderingVideo() => Video(
  width: 160,
  height: 284,
  scenes: [
    Scene(
      duration: 2.seconds,
      background: Background.color(_bg),
      camera: const Camera.push(zoom: 1.4, toward: Alignment.topRight),
      children: [
        Center(
          child: SizedBox(
            width: 80,
            height: 80,
            child: const Box(color: _tile).animate([Animation.scaleIn(from: 0.2)]),
          ),
        ),
      ],
    ),
  ],
);

// The hero pair (a Box logo) crossfading across a boundary, with a push on the
// incoming scene — the morph follows the camera because the slot rects are
// measured through the transform (D8).
Video _heroUnderCameraVideo() {
  final logo = Anchor('logo');
  return Video(
    width: 160,
    height: 284,
    transition: Transition.crossFade(15.frames),
    scenes: [
      Scene(
        duration: 2.seconds,
        background: Background.color(_bg),
        children: [
          Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: SharedElement(
                anchor: logo,
                child: const Box(color: _logo),
              ),
            ),
          ),
        ],
      ),
      Scene(
        duration: 2.seconds,
        background: Background.color(_scene2),
        camera: const Camera.push(zoom: 1.4, toward: Alignment.bottomRight),
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 32,
                height: 32,
                child: SharedElement(
                  anchor: logo,
                  child: const Box(color: _logo),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

GoldenTestScenario _scenario(String name, int frame, Video video) => GoldenTestScenario(
  name: name,
  child: SizedBox(
    width: _canvas.width,
    height: _canvas.height,
    child: RenderControllerScope(
      controller: RenderController(initialFrame: frame),
      child: video,
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'camera push toward topRight, mid-over: the grid magnified about the corner',
    fileName: 'camera_push_mid',
    builder: () => GoldenTestGroup(
      children: [
        _scenario(
          'frame 30 (q = 0.5)',
          30,
          _cameraVideo(const Camera.push(zoom: 1.4, toward: Alignment.topRight)),
        ),
      ],
    ),
  );

  await goldenTest(
    'camera pan: focal at the top-left start, then the bottom-right end',
    fileName: 'camera_pan_start',
    builder: () => GoldenTestGroup(
      children: [
        _scenario(
          'frame 0 (focal topLeft)',
          0,
          _cameraVideo(
            const Camera.pan(from: Alignment.topLeft, to: Alignment.bottomRight, zoom: 1.4),
          ),
        ),
      ],
    ),
  );

  await goldenTest(
    'camera pan end: focal arrived at the bottom-right',
    fileName: 'camera_pan_end',
    builder: () => GoldenTestGroup(
      children: [
        _scenario(
          'frame 59 (focal bottomRight)',
          59,
          _cameraVideo(
            const Camera.pan(from: Alignment.topLeft, to: Alignment.bottomRight, zoom: 1.4),
          ),
        ),
      ],
    ),
  );

  await goldenTest(
    'camera ordering: a scaleIn Box inside a pushing scene, both mid-flight',
    fileName: 'camera_ordering',
    builder: () => GoldenTestGroup(
      children: [_scenario('frame 10 (camera + element)', 10, _orderingVideo())],
    ),
  );

  await goldenTest(
    'hero under camera: the morph follows the pushing incoming scene',
    fileName: 'hero_under_camera',
    builder: () => GoldenTestGroup(
      children: [_scenario('frame 52 (mid blend, mid push)', 52, _heroUnderCameraVideo())],
    ),
  );
}
