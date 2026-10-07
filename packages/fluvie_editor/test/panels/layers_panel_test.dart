import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiReorderable, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-back', 'type': 'Text', 'text': 'back'},
        {'id': 'el-front', 'type': 'Text', 'text': 'front'},
      ],
    },
  ],
  'editor': {
    'editorSchema': 1,
    'elements': {
      'el-back': {'name': 'Backdrop'},
    },
  },
};

final class _Harness {
  _Harness(this.container, this.history);
  final ProviderContainer container;
  final DocumentHistory history;
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => SizedBox(
            width: 220,
            child: LayersPanel(document: history.document, slide: 0, onCommand: history.dispatch),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, history);
}

void main() {
  testWidgets('layers list topmost first, named from the editor block', (tester) async {
    await _pump(tester);
    final front = tester.getTopLeft(find.text('Text'));
    final backdrop = tester.getTopLeft(find.text('Backdrop'));
    expect(front.dy, lessThan(backdrop.dy));
  });

  testWidgets('tapping a row selects the element', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Backdrop'));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-back'});
  });

  testWidgets('double-tap renames through the command layer', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('Text'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Title');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.history.document.elementMeta('el-front')['name'], 'Title');
    expect(find.text('Title'), findsOneWidget);
    harness.history.undo();
    expect(harness.history.document.elementMeta('el-front')['name'], isNull);
  });

  testWidgets('lock stays editor metadata; hide writes spec visible', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Lock Text'));
    await tester.pump();
    expect(harness.history.document.elementMeta('el-front')['locked'], isTrue);
    expect(find.bySemanticsLabel('Unlock Text'), findsOneWidget);

    final digestBefore = harness.history.document.renderDigest;
    await tester.tap(find.bySemanticsLabel('Hide Text'));
    await tester.pump();
    expect(harness.history.document.elementJson('el-front')?['visible'], false);
    expect(harness.history.document.elementMeta('el-front')['hidden'], isNull);
    expect(harness.history.document.renderDigest, isNot(digestBefore));
    expect(find.bySemanticsLabel('Show Text'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Show Text'));
    await tester.pump();
    expect(harness.history.document.elementJson('el-front')?.containsKey('visible'), isFalse);

    harness.history
      ..undo()
      ..undo()
      ..undo();
    expect(harness.history.document.elementMeta('el-front')['locked'], isNull);
    expect(harness.history.document.elementJson('el-front')?.containsKey('visible'), isFalse);
  });

  testWidgets('dragging rows maps back to z-order commands', (tester) async {
    final harness = await _pump(tester);
    // Move the top row (front) below the backdrop: panel 0 -> 2 means
    // z-index 0 in a two-element scene.
    tester.widget<OiReorderable>(find.byType(OiReorderable)).onReorder(0, 2);
    await tester.pump();
    expect(harness.history.document.elementIdsInScene(0), ['el-front', 'el-back']);
  });
}
