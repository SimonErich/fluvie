// The editor canvas warms what its composition paints with: a curves or
// LUT effect added from the Effects tab grades on the stage, and the frames
// before the warm lands show the child ungraded instead of an error.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart' show ColorLookupScope, WarmShaderScope;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-a',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'effects': [
            {
              'kind': 'curves',
              'curves': {
                'master': [
                  [0, 0],
                  [0.5, 0.2],
                  [1, 1],
                ],
              },
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  testWidgets('a curves effect grades on the stage once the canvas warms', (tester) async {
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 320,
            height: 180,
            child: EditorCanvas(document: EditorDocument.fromJson(_deck()), slide: 0),
          ),
        ),
      ),
    );
    await tester.pump();

    // Before the warm lands: no error, the composition still shows.
    expect(tester.takeException(), isNull);

    // Let the warm pass run, then rebuild: the scopes are mounted.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(WarmShaderScope), findsOneWidget);
    expect(find.byType(ColorLookupScope), findsOneWidget);
  });
}
