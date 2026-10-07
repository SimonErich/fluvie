@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

/// Four distinctly colored boxes, freeform. Each scenario wraps them into
/// one smart block; the golden renders the SPEC the reflow wrote — a block
/// is sugar over real geometry, so the plain scene build is the truth.
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
          'id': 'el-1',
          'type': 'Box',
          'color': '#6C5CE7',
          'cornerRadius': 4,
          'transform': {'x': 0.2, 'y': 0.3, 'w': 0.25, 'h': 0.3},
        },
        {
          'id': 'el-2',
          'type': 'Box',
          'color': '#0984E3',
          'cornerRadius': 4,
          'transform': {'x': 0.7, 'y': 0.3, 'w': 0.25, 'h': 0.3},
        },
        {
          'id': 'el-3',
          'type': 'Box',
          'color': '#2ECC8F',
          'cornerRadius': 4,
          'transform': {'x': 0.2, 'y': 0.7, 'w': 0.25, 'h': 0.3},
        },
        {
          'id': 'el-4',
          'type': 'Box',
          'color': '#FDCB6E',
          'cornerRadius': 4,
          'transform': {'x': 0.7, 'y': 0.7, 'w': 0.25, 'h': 0.3},
        },
      ],
    },
  ],
};

Widget _blockScene(BlockKind kind) {
  final document = MakeBlockCommand(
    scene: 0,
    ids: const ['el-1', 'el-2', 'el-3', 'el-4'],
    groupId: 'el-block',
    transform: const {'x': 0.5, 'y': 0.5, 'w': 0.9, 'h': 0.8},
    block: BlockSpec.defaults(kind),
  ).apply(EditorDocument.fromJson(_deck()));
  return OiThemeScope(
    data: OiThemeData.dark(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 320,
        height: 180,
        child: EditorCanvas(document: document, slide: 0, fitMargin: 0),
      ),
    ),
  );
}

Future<void> main() async {
  await goldenTest(
    'each block kind arranges the same four boxes',
    fileName: 'block_kinds',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final kind in BlockKind.values)
          GoldenTestScenario(name: 'the ${kind.name} block', child: _blockScene(kind)),
      ],
    ),
  );
}
