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
          'type': 'Box',
          'color': '#26FFFFFF',
          'transform': {'x': 0.5, 'y': 0.9, 'w': 1.0, 'h': 0.08},
        },
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.3, 'w': 0.8, 'h': 0.2},
        },
      ],
    },
  },
  'scenes': [
    {'duration': '60f', 'master': 'base', 'children': <Object?>[]},
  ],
};

Future<(List<EditorCommand>, List<int>)> _pump(WidgetTester tester) async {
  final commands = <EditorCommand>[];
  final closes = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: MasterEditor(
          session: MasterEditSession(EditorDocument.fromJson(_deck()), 'base'),
          onCommand: commands.add,
          onClose: () => closes.add(1),
        ),
      ),
    ),
  );
  await tester.pump();
  return (commands, closes);
}

void main() {
  testWidgets('shows the master on the canvas with its slot labels', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Editing master "base"'), findsOneWidget);
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.text('title'), findsOneWidget);
    final canvas = tester.widget<EditorCanvas>(find.byType(EditorCanvas));
    expect(canvas.document.elementIdsInScene(0), ['m-0', 's-1']);
  });

  testWidgets('Done leaves master-edit mode', (tester) async {
    final (_, closes) = await _pump(tester);
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(closes, hasLength(1));
  });

  testWidgets('canvas edits arrive translated onto the real document', (tester) async {
    final (commands, _) = await _pump(tester);
    final canvas = tester.widget<EditorCanvas>(find.byType(EditorCanvas));
    canvas.onCommand!(
      const SetTransformCommand(
        id: 'm-0',
        transform: {'x': 0.5, 'y': 0.1, 'w': 1.0, 'h': 0.08},
      ),
    );
    final command = commands.single as SetMasterCommand;
    expect(command.name, 'base');
    final chrome = (command.master!['children']! as List).first! as Map<String, Object?>;
    expect(chrome['transform'], {'x': 0.5, 'y': 0.1, 'w': 1.0, 'h': 0.08});
  });

  testWidgets('untranslatable edits dispatch nothing', (tester) async {
    final (commands, _) = await _pump(tester);
    final canvas = tester.widget<EditorCanvas>(find.byType(EditorCanvas));
    canvas.onCommand!(const RemoveElementCommand(id: 's-1'));
    expect(commands, isEmpty);
  });
}
