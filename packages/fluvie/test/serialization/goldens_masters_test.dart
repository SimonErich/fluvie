// The masters golden, spec-built: two slides adopt the same "content"
// master — the shared accent footer and dark backdrop are the master's, the
// differing titles are per-scene fills (slide one overrides the slot
// transform and adds a freeform yellow tag; slide two keeps the slot
// placement, leaves the body slot unfilled, and brings its own background) —
// so the shared chrome and the per-scene differences render side by side.
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

/// Two scenes of one master plus their fills: shared chrome from the master,
/// differing titles from the scenes.
Map<String, Object?> _masteredDeck() => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'masters': {
    'content': {
      'background': {'kind': 'color', 'color': '#FF101018'},
      'layout': 'canvas',
      'children': [
        {
          'type': 'Box',
          'color': '#FF6C5CE7',
          'transform': {'x': 0.5, 'y': 0.94, 'w': 1.0, 'h': 0.06},
        },
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.3, 'w': 0.9, 'h': 0.3},
          'style': {'color': '#FFF5F6FA', 'fontSize': 34, 'fontWeight': 'w700'},
        },
        {
          'type': 'Placeholder',
          'slot': 'body',
          'transform': {'x': 0.5, 'y': 0.62, 'w': 0.86, 'h': 0.25},
        },
      ],
    },
  },
  'scenes': [
    {
      'duration': '90f',
      'layout': 'canvas',
      'master': 'content',
      'fills': {
        'title': {
          'type': 'Text',
          'id': 's1-title',
          'text': 'Slide one',
          'textAlign': 'center',
          'transform': {'x': 0.5, 'y': 0.14, 'w': 0.9, 'h': 0.24},
        },
        'body': {
          'type': 'Text',
          'id': 's1-body',
          'text': 'filled body',
          'textAlign': 'center',
          'style': {'color': '#FFB2BEC3', 'fontSize': 20},
        },
      },
      'children': [
        {
          'type': 'Box',
          'id': 's1-extra',
          'color': '#FFFFD166',
          'transform': {'x': 0.85, 'y': 0.1, 'w': 0.16, 'h': 0.1},
        },
      ],
    },
    {
      'duration': '90f',
      'background': {'kind': 'color', 'color': '#FF2D3436'},
      'layout': 'canvas',
      'master': 'content',
      'fills': {
        'title': {'type': 'Text', 'id': 's2-title', 'text': 'Slide two', 'textAlign': 'center'},
      },
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
    'two slides of one master share its chrome and differ by their fills',
    fileName: 'mastered_scenes',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(name: 'slide one', child: _mounted(_masteredDeck(), frame: 45)),
        GoldenTestScenario(name: 'slide two', child: _mounted(_masteredDeck(), frame: 135)),
      ],
    ),
  );
}
