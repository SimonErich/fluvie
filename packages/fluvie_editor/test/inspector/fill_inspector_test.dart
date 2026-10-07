import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'masters': {
    'base': {
      'children': [
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2},
        },
      ],
    },
  },
  'scenes': [
    {
      'duration': '60f',
      'master': 'base',
      'fills': {
        'title': {'id': 'el-fill', 'type': 'Text', 'text': 'Filled'},
      },
      'children': [
        {
          'id': 'el-plain',
          'type': 'Text',
          'text': 'Plain',
          'transform': {'x': 0.5, 'y': 0.8},
        },
      ],
    },
  ],
};

Future<void> _pump(WidgetTester tester, String selected) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(selectionProvider.notifier).select({selected});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: SizedBox(
          width: 280,
          child: EditorInspector(
            document: EditorDocument.fromJson(_deck()),
            slide: 0,
            onCommand: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a fill names its slot instead of the Arrange row', (tester) async {
    await _pump(tester, 'el-fill');
    expect(find.text('Fills slot "title" of master "base"'), findsOneWidget);
    expect(find.bySemanticsLabel('Bring forward'), findsNothing);
    expect(find.bySemanticsLabel('Send backward'), findsNothing);
  });

  testWidgets('a plain element keeps the Arrange row', (tester) async {
    await _pump(tester, 'el-plain');
    expect(find.bySemanticsLabel('Bring forward'), findsOneWidget);
    expect(find.textContaining('Fills slot'), findsNothing);
  });
}
