import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiThemeData;

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
          'id': 'el-title',
          'type': 'Text',
          'text': 'Hello',
          'style': {'color': '#F9FAFB', 'fontSize': 24},
          'transform': {'x': 0.25, 'y': 0.5, 'w': 0.5, 'h': 0.25},
        },
        {
          'id': 'el-box',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.75, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.history);
  final ProviderContainer container;
  final DocumentHistory history;
}

Future<_Harness> _pump(WidgetTester tester, {Set<String> selected = const {}}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  container.read(selectionProvider.notifier).select(selected);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 280,
                child: EditorInspector(
                  document: history.document,
                  slide: 0,
                  onCommand: history.dispatch,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, history);
}

/// The nth EditableText on screen (the property grid's field order).
Finder _field(int index) => find.byType(EditableText).at(index);

void main() {
  testWidgets('nothing selected edits the slide size undoably', (tester) async {
    final harness = await _pump(tester);
    expect(find.text('Slide'), findsOneWidget);
    expect(find.text('Background'), findsOneWidget);

    // The first field is the slide width.
    await tester.enterText(_field(0), '640');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.history.document.toJson()['size'], {'width': 640, 'height': 180});
    harness.history.undo();
    expect(harness.history.document.toJson()['size'], {'width': 320, 'height': 180});
  });

  testWidgets('nothing selected edits the background kind and color', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.byType(OiSelect<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('color').last);
    await tester.pumpAndSettle();
    expect(
      harness.history.document.sceneJson(0)['background'],
      {'kind': 'color', 'color': '#101018'},
    );

    // The swatch opens the picker; picking commits a coalescing patch.
    await tester.tap(find.bySemanticsLabel('Background color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '#FF0000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      harness.history.document.sceneJson(0)['background'],
      {'kind': 'color', 'color': '#FFFF0000'},
    );
  });

  testWidgets('a selection edits exact transform values in pixels', (tester) async {
    final harness = await _pump(tester, selected: {'el-title'});
    expect(find.text('Transform'), findsOneWidget);

    // X shows 80 (0.25 * 320); type 160 to land at x = 0.5.
    expect(tester.widget<EditableText>(_field(0)).controller.text, '80');
    await tester.enterText(_field(0), '160');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final transform =
        harness.history.document.elementJson('el-title')!['transform']! as Map<String, Object?>;
    expect(transform['x'], closeTo(0.5, 1e-9));
    expect(harness.history.undoLabel, 'Move el-title');
  });

  testWidgets('opacity writes into the transform and 1 clears it', (tester) async {
    final harness = await _pump(tester, selected: {'el-title'});
    // Fields: X, Y, W, H, Angle, Opacity — opacity is index 5.
    await tester.enterText(_field(5), '0.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    var transform =
        harness.history.document.elementJson('el-title')!['transform']! as Map<String, Object?>;
    expect(transform['opacity'], closeTo(0.5, 1e-9));

    await tester.enterText(_field(5), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    transform =
        harness.history.document.elementJson('el-title')!['transform']! as Map<String, Object?>;
    expect(transform.containsKey('opacity'), isFalse);
  });

  testWidgets('the style section edits type-specific fields undoably', (tester) async {
    final harness = await _pump(tester, selected: {'el-title'});
    // Style fields follow the transform block: text, then font size.
    await tester.enterText(_field(6), 'Changed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.history.document.elementJson('el-title')!['text'], 'Changed');

    await tester.enterText(_field(7), '48');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final style =
        harness.history.document.elementJson('el-title')!['style']! as Map<String, Object?>;
    expect(style['fontSize'], 48);
    expect(style['color'], '#F9FAFB', reason: 'nested style keys survive a patch');

    harness.history
      ..undo()
      ..undo();
    expect(harness.history.document.elementJson('el-title')!['text'], 'Hello');
  });

  testWidgets('arrange buttons reorder the element', (tester) async {
    final harness = await _pump(tester, selected: {'el-title'});
    await tester.tap(find.bySemanticsLabel('Bring forward'));
    await tester.pump();
    expect(harness.history.document.elementIdsInScene(0), ['el-box', 'el-title']);
  });

  testWidgets('a multi-selection says how many are selected', (tester) async {
    await _pump(tester, selected: {'el-title', 'el-box'});
    expect(find.text('2 elements selected'), findsOneWidget);
  });
}
