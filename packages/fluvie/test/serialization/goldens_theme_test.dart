// The theme-token golden, spec-built: the scene background is a palette
// token, the headline adopts the "heading" type-scale token whole, the
// caption bases on "body" but overrides its color with a literal, and the
// accent bar reads the "accent" palette token next to a literal yellow twin —
// so literal and token styling render side by side from one theme.
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

/// A themed scene: token background and headline, a caption whose literal
/// color overrides its style token, and one token-tinted plus one
/// literal-tinted bar.
Map<String, Object?> _themedScene() => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'theme': {
    'palette': {'accent': '#FF6C5CE7', 'surface': '#FF101018'},
    'typeScale': {
      'heading': {'color': '#FFF5F6FA', 'fontSize': 40, 'fontWeight': 'w700'},
      'body': {'color': '#FFB2BEC3', 'fontSize': 18},
    },
  },
  'scenes': [
    {
      'duration': '90f',
      'layout': 'canvas',
      'background': {
        'kind': 'color',
        'color': {'token': 'surface'},
      },
      'children': [
        {
          'type': 'Text',
          'text': 'Design tokens',
          'textAlign': 'center',
          'style': {'token': 'heading'},
          'transform': {'x': 0.5, 'y': 0.3, 'w': 0.9, 'h': 0.3},
        },
        {
          'type': 'Text',
          'text': 'literal beats token',
          'textAlign': 'center',
          'style': {'token': 'body', 'color': '#FFFFD166'},
          'transform': {'x': 0.5, 'y': 0.55, 'w': 0.9, 'h': 0.2},
        },
        {
          'type': 'Box',
          'color': {'token': 'accent'},
          'transform': {'x': 0.3, 'y': 0.8, 'w': 0.3, 'h': 0.12},
        },
        {
          'type': 'Box',
          'color': '#FFFFD166',
          'transform': {'x': 0.7, 'y': 0.8, 'w': 0.3, 'h': 0.12},
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
    'theme tokens style the background, headline, and accent beside literals',
    fileName: 'themed_scene',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'themed scene', child: _mounted(_themedScene(), frame: 45)),
      ],
    ),
  );
}
