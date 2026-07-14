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

/// One scene, two ways: positioned children on a canvas layout next to the
/// stacked default — the pin that keeps `Placed` geometry from drifting.
Map<String, Object?> _scene({required bool positioned}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '30f',
      if (positioned) 'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#14141C'},
      'children': [
        {
          'type': 'Box',
          'color': '#6C5CE7',
          'size': {'width': 0.2, 'height': 0.25},
          if (positioned) 'transform': {'x': 0.25, 'y': 0.3},
        },
        {
          'type': 'Box',
          'color': '#2ECC8F',
          if (positioned) 'transform': {'x': 0.7, 'y': 0.7, 'w': 0.4, 'h': 0.3, 'rotation': 10},
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
    'placement lays out a canvas scene deterministically',
    fileName: 'placement_scene',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(name: 'canvas layout', child: _mounted(_scene(positioned: true))),
        GoldenTestScenario(name: 'stacked default', child: _mounted(_scene(positioned: false))),
      ],
    ),
  );
}
