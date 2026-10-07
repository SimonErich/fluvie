import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Future<(List<Map<String, Object?>>, List<int>)> _pump(
  WidgetTester tester,
  Map<String, Object?> element,
) async {
  final patches = <Map<String, Object?>>[];
  final deletes = <int>[];
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: Center(
        child: SelectionToolbar(
          element: element,
          onPatch: patches.add,
          onDelete: () => deletes.add(1),
        ),
      ),
    ),
  );
  await tester.pump();
  return (patches, deletes);
}

void main() {
  testWidgets('text gets font-size steps, a color swatch, and delete', (tester) async {
    final (patches, deletes) = await _pump(tester, const {
      'type': 'Text',
      'text': 'Hello',
      'style': {'fontSize': 32, 'color': '#F9FAFB'},
    });
    expect(find.bySemanticsLabel('Text color'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Larger text'));
    expect((patches.single['style']! as Map)['fontSize'], 36);
    await tester.tap(find.bySemanticsLabel('Smaller text'));
    expect((patches.last['style']! as Map)['fontSize'], 28);
    // Untouched style keys survive.
    expect((patches.last['style']! as Map)['color'], '#F9FAFB');

    await tester.tap(find.bySemanticsLabel('Delete element'));
    expect(deletes, hasLength(1));
  });

  testWidgets('a shape gets its color swatch and delete', (tester) async {
    await _pump(tester, const {'type': 'Shape', 'kind': 'rect', 'color': '#6C5CE7'});
    expect(find.bySemanticsLabel('Element color'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete element'), findsOneWidget);
    expect(find.bySemanticsLabel('Larger text'), findsNothing);
  });

  testWidgets('media keeps just delete', (tester) async {
    await _pump(tester, const {
      'type': 'Image',
      'source': {'kind': 'asset', 'value': 'p.png'},
    });
    expect(find.bySemanticsLabel('Delete element'), findsOneWidget);
    expect(find.bySemanticsLabel('Element color'), findsNothing);
    expect(find.bySemanticsLabel('Text color'), findsNothing);
  });
}
