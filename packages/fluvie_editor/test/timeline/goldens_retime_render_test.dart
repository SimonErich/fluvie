@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

/// A spec-built slide whose box travels in through a keyframes animation
/// (frames 0..30). Held at frame 15 the render changes visibly when the
/// animation is retimed by 12 frames — the acceptance pair for Epic 6.3.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#14141C'},
      'children': [
        {
          'id': 'el-hero',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.3},
          'animate': [
            {
              'keyframes': [
                {'opacity': 0, 'x': -1},
                {'opacity': 1, 'x': 0.1},
                <String, Object?>{},
              ],
              'positions': ['0f', '20f', '30f'],
              'duration': '30f',
            },
          ],
        },
      ],
    },
  ],
};

Widget _canvasAt(EditorDocument document) {
  final transport = SlideTransport(fps: 30, length: 60, initialFrame: 15);
  addTearDown(transport.dispose);
  return OiThemeScope(
    data: OiThemeData.dark(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 320,
        height: 180,
        child: EditorCanvas(document: document, slide: 0, fitMargin: 0, transport: transport),
      ),
    ),
  );
}

Future<void> main() async {
  final before = EditorDocument.fromJson(_deck());
  final after = const SetAnimationDelayCommand(
    id: 'el-hero',
    index: 0,
    delayFrames: 12,
  ).apply(before);

  await goldenTest(
    'the same held frame renders differently after a retime',
    fileName: 'timeline_retime_render',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'before the retime (frame 15 of 0..30)', child: _canvasAt(before)),
        GoldenTestScenario(
          name: 'after a 12-frame retime (frame 15 of 12..42)',
          child: _canvasAt(after),
        ),
      ],
    ),
  );
}
