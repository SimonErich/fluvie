// The Group golden, spec-built: an off-center outer group carrying a card,
// two boxes, a nested inner group with a rotated accent, and one hidden
// child. Every child transform is a fraction of the group's box, so the whole
// arrangement sits left of center as one unit — and the hidden bright-red box
// would cover most of the card if `visible: false` leaked a single pixel.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

const _width = 480.0;
const _height = 270.0;

/// A nested-group scene: the outer group (faded in as one unit by the golden
/// frame) holds everything left of center; a caption on the right pins the
/// canvas scale.
Map<String, Object?> _groupScene() => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#101018'},
      'children': [
        {
          'type': 'Group',
          'transform': {'x': 0.35, 'y': 0.5, 'w': 0.55, 'h': 0.72},
          'animate': [
            {'preset': 'fadeIn', 'duration': '15f'},
          ],
          'children': [
            {
              'type': 'Box',
              'decoration': {'color': '#1B1B24', 'cornerRadius': 14},
              'transform': {'x': 0.5, 'y': 0.5, 'w': 1.0, 'h': 1.0},
            },
            {
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.3, 'y': 0.28, 'w': 0.4, 'h': 0.3},
            },
            {
              'type': 'Box',
              'color': '#2ECC8F',
              'transform': {'x': 0.75, 'y': 0.28, 'w': 0.3, 'h': 0.3},
            },
            {
              'type': 'Group',
              'transform': {'x': 0.5, 'y': 0.72, 'w': 0.8, 'h': 0.4},
              'children': [
                {
                  'type': 'Box',
                  'color': '#F0D86A',
                  'transform': {'x': 0.5, 'y': 0.5, 'w': 0.7, 'h': 0.6, 'rotation': 18},
                },
              ],
            },
            {
              'type': 'Box',
              'color': '#FF1B1B',
              'visible': false,
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.95, 'h': 0.95},
            },
          ],
        },
        {
          'type': 'Text',
          'text': 'grouped',
          'textAlign': 'center',
          'style': {'fontSize': 18, 'color': '#B2BEC3'},
          'transform': {'x': 0.8, 'y': 0.5, 'w': 0.35, 'h': 0.2},
        },
      ],
    },
  ],
};

Widget _mounted(Map<String, Object?> json, {required int frame}) => RenderModeContext(
  mode: RenderMode.capture,
  child: RenderControllerScope(
    controller: RenderController(initialFrame: frame),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: _width,
        height: _height,
        child: VideoSpec.fromJson(json).build(),
      ),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'nested groups paint off-center as one unit and hide their hidden child',
    fileName: 'group_scene',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'nested groups', child: _mounted(_groupScene(), frame: 70)),
      ],
    ),
  );
}
