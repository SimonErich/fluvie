// The keyframes render-equivalence pin: the same multi-stop animation
// authored as widgets and parsed from spec JSON, mounted side by side at the
// same frames in one golden. Every row must show two identical halves — if
// the codec, the builder, or the constructor mapping drifts, the halves
// diverge and the golden fails.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

const _width = 240.0;
const _height = 180.0;

/// The spec side: the keyframes animation exactly as an editor writes it.
Map<String, Object?> _specDocument() => {
  'fluvieSpec': 1,
  'size': {'width': 240, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'background': {'kind': 'color', 'color': '#101018'},
      'children': [
        {
          'type': 'Box',
          'color': '#6C5CE7',
          'size': {'width': 0.4, 'height': 0.3},
          'animate': [
            {
              'keyframes': [
                {'opacity': 0, 'y': 0.6},
                {'opacity': 1, 'y': -0.15},
                {'y': 0},
              ],
              'easings': ['out', 'smooth'],
              'positions': ['0f', '10f', '24f'],
              'duration': '24f',
              'at': 'sceneStart',
            },
          ],
        },
      ],
    },
  ],
};

/// The widget side: the same video authored with the Dart constructors the
/// spec builder calls.
Video _widgetVideo() => Video(
  size: const VideoSize(240, 180),
  scenes: [
    Scene(
      duration: const Time.frames(60),
      background: Background.color(const Color(0xFF101018)),
      children: [
        const Box(
          color: Color(0xFF6C5CE7),
          size: Size(0.4, 0.3),
        ).animate([
          Animation.keyframes(
            const [Keyframe(opacity: 0, y: 0.6), Keyframe(opacity: 1, y: -0.15), Keyframe(y: 0)],
            easings: const [Ease.out, Ease.smooth],
            at: const [Time.zero, Time.frames(10), Time.frames(24)],
            duration: const Time.frames(24),
            trigger: Trigger.sceneStart,
          ),
        ]),
      ],
    ),
  ],
);

Widget _mounted(Widget video, {required int frame}) => RenderModeContext(
  mode: RenderMode.capture,
  child: RenderControllerScope(
    controller: RenderController(initialFrame: frame),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: _width, height: _height, child: video),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'a keyframes animation renders identically from widgets and from spec',
    fileName: 'keyframes_equivalence',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final frame in const [6, 12, 18]) ...[
          GoldenTestScenario(
            name: 'widgets, frame $frame',
            child: _mounted(_widgetVideo(), frame: frame),
          ),
          GoldenTestScenario(
            name: 'from spec, frame $frame',
            child: _mounted(VideoSpec.fromJson(_specDocument()).build(), frame: frame),
          ),
        ],
      ],
    ),
  );
}
