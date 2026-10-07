@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

/// A fixture deck bound entirely to the shared builtin token vocabulary:
/// a token background, a surface panel, an accent bar, and type-scale
/// typography — so switching the theme restyles every element.
Map<String, Object?> _boundDeck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {
        'kind': 'color',
        'color': {'token': 'background'},
      },
      'children': [
        {
          'id': 'el-panel',
          'type': 'Box',
          'color': {'token': 'surface'},
          'cornerRadius': 12,
          'transform': {'x': 0.5, 'y': 0.52, 'w': 0.9, 'h': 0.78},
        },
        {
          'id': 'el-accent',
          'type': 'Box',
          'color': {'token': 'accent'},
          'transform': {'x': 0.5, 'y': 0.86, 'w': 0.5, 'h': 0.06},
        },
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Fluvie',
          'style': {
            'token': 'title',
            'fontSize': 40,
            'color': {'token': 'text'},
          },
          'transform': {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.3},
        },
        {
          'id': 'el-caption',
          'type': 'Text',
          'text': 'themes restyle the deck',
          'style': {
            'token': 'caption',
            'color': {'token': 'muted'},
          },
          'transform': {'x': 0.5, 'y': 0.6, 'w': 0.8, 'h': 0.2},
        },
      ],
    },
  ],
};

Widget _slide(String themeName) {
  final document = SetThemeCommand(
    theme: builtinThemes[themeName],
    verb: 'Apply',
  ).apply(EditorDocument.fromJson(_boundDeck()));
  final transport = SlideTransport(fps: 30, length: 60, initialFrame: 30);
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
  await goldenTest(
    'one bound deck restyles under each builtin theme',
    fileName: 'theme_switch',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        for (final name in builtinThemes.keys)
          GoldenTestScenario(name: 'the $name theme', child: _slide(name)),
      ],
    ),
  );
}
