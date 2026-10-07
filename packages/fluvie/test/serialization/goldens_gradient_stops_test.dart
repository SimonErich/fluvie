// The gradient-stops golden, spec-built: the scene background is a
// three-stop linear gradient whose middle stop sits at 0.15 (not the even
// 0.5), so the violet band crowds the top; the box's decoration gradient
// skews its two stops to 0.2..0.9. Under even spacing both would read as
// balanced ramps, so a regression to even spacing changes the image clearly.
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

/// A scene with skewed gradient stops on both surfaces: the background's
/// middle color pinned near the top, and a box whose decoration ramp starts
/// late and ends early.
Map<String, Object?> _skewedScene() => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'scenes': [
    {
      'duration': '90f',
      'layout': 'canvas',
      'background': {
        'kind': 'gradient',
        'colors': ['#FF0B0B1E', '#FF6C5CE7', '#FF26D0CE'],
        'stops': [0, 0.15, 1],
        'begin': 'topCenter',
        'end': 'bottomCenter',
      },
      'children': [
        {
          'type': 'Box',
          'decoration': {
            'cornerRadius': 12,
            'gradient': {
              'colors': ['#FFFFD166', '#FFFF2D55'],
              'stops': [0.2, 0.9],
            },
          },
          'transform': {'x': 0.5, 'y': 0.72, 'w': 0.7, 'h': 0.3},
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
    'gradient stops skew the background and decoration ramps away from even spacing',
    fileName: 'gradient_stops',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'skewed stops', child: _mounted(_skewedScene(), frame: 45)),
      ],
    ),
  );
}
