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

/// The wave-1 annotation elements, spec-built: the same JSON an editor
/// writes must paint the same strokes the widgets paint.
Map<String, Object?> _scene() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '30f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#14141C'},
      'children': [
        {
          'type': 'Shape',
          'kind': 'line',
          'from': {'x': 20, 'y': 160},
          'to': {'x': 140, 'y': 160},
          'color': '#6C5CE7',
          'strokeWidth': 4,
        },
        {
          'type': 'Shape',
          'kind': 'rect',
          'rect': {'x': 20, 'y': 20, 'w': 60, 'h': 40},
          'color': '#2ECC8F',
        },
        {
          'type': 'Shape',
          'kind': 'circle',
          'center': {'x': 160, 'y': 50},
          'radius': 25,
          'color': '#F0D86A',
        },
        {
          'type': 'Shape',
          'kind': 'path',
          'path': 'M 210 20 L 280 20 Q 300 50 280 80 L 210 80 Z',
          'color': '#E17055',
          'strokeWidth': 2,
        },
        {
          'type': 'Arrow',
          'from': {'x': 40, 'y': 130},
          'to': {'x': 150, 'y': 90},
          'color': '#74B9FF',
          'headLength': 14,
        },
        {
          'type': 'Connector',
          'from': {'x': 180, 'y': 120},
          'to': {'x': 290, 'y': 160},
          'elbow': true,
          'color': '#FD79A8',
        },
      ],
    },
  ],
};

Widget _mounted(Map<String, Object?> json) => RenderModeContext(
  mode: RenderMode.capture,
  child: RenderControllerScope(
    controller: RenderController(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 320, height: 180, child: VideoSpec.fromJson(json).build()),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'wave-1 annotations paint from the spec exactly as widgets',
    fileName: 'wave1_annotations',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'annotations scene', child: _mounted(_scene())),
      ],
    ),
  );
}
