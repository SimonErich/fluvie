import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show SlidePreviewService;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiReorderable, OiThemeData;

Map<String, Object?> _deck({int scenes = 4}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    for (var s = 0; s < scenes; s++)
      {
        'duration': '60f',
        'children': [
          {'id': 'el-$s', 'type': 'Text', 'text': 'slide $s'},
        ],
      },
  ],
};

Future<ui.Image> _stub(int slide) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF123456),
  );
  return recorder.endRecording().toImage(4, 4);
}

Future<DocumentHistory> _pump(WidgetTester tester, EditorDocument document) async {
  final service = SlidePreviewService(renderSlide: _stub);
  addTearDown(service.dispose);
  final history = DocumentHistory(document);
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: ListenableBuilder(
        listenable: history,
        builder: (context, _) => SizedBox(
          width: 180,
          child: SlideStrip(
            document: history.document,
            current: 0,
            service: service,
            onSelect: (_) {},
            onCommand: history.dispatch,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return history;
}

/// The deck with a section marker on [at].
EditorDocument _marked(EditorDocument document, int at, String name) => document.setSceneMeta(at, {
  'section': {'name': name},
});

Future<void> _rightClick(WidgetTester tester, Finder finder) async {
  final where = tester.getCenter(finder);
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.addPointer(location: where);
  await tester.pump();
  await gesture.down(where);
  await tester.pump();
  await gesture.up();
  // Removed right away so a test can right-click more than once.
  await gesture.removePointer();
  await tester.pumpAndSettle();
}

/// The slide order as element ids.
List<String> _order(EditorDocument document) => [
  for (var s = 0; s < document.sceneCount; s++) document.elementIdsInScene(s).single,
];

void main() {
  testWidgets('without sections the strip stays a flat reorderable list', (tester) async {
    await _pump(tester, EditorDocument.fromJson(_deck()));
    expect(find.byType(OiReorderable), findsOneWidget);
  });

  testWidgets('a named section renders its header above its tiles', (tester) async {
    final document = _marked(EditorDocument.fromJson(_deck()), 2, 'Closing');
    await _pump(tester, document);
    expect(find.text('Closing'), findsOneWidget);
    for (final tile in const ['1', '2', '3', '4']) {
      expect(find.text(tile), findsOneWidget);
    }
    // The header sits between tile 2 and tile 3.
    expect(
      tester.getTopLeft(find.text('Closing')).dy,
      greaterThan(tester.getTopLeft(find.text('2')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Closing')).dy,
      lessThan(tester.getTopLeft(find.text('3')).dy),
    );
  });

  testWidgets('collapsing a section hides its tiles and undoes as a command', (tester) async {
    final document = _marked(EditorDocument.fromJson(_deck()), 2, 'Closing');
    final history = await _pump(tester, document);
    await tester.tap(find.bySemanticsLabel('Collapse Closing'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
    expect(find.text('4'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.bySemanticsLabel('Expand Closing'), findsOneWidget);
    expect(history.document.sceneMeta(2)['section'], {'name': 'Closing', 'collapsed': true});

    history.undo();
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    history.redo();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Expand Closing'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(history.document.sceneMeta(2)['section'], {'name': 'Closing'});
  });

  testWidgets('the header menu moves a section as one unit', (tester) async {
    var document = EditorDocument.fromJson(_deck());
    document = _marked(document, 0, 'Opening');
    document = _marked(document, 2, 'Closing');
    final history = await _pump(tester, document);
    await _rightClick(tester, find.text('Closing'));
    await tester.tap(find.text('Move section up'));
    await tester.pumpAndSettle();
    expect(_order(history.document), ['el-2', 'el-3', 'el-0', 'el-1']);
    final sections = deckSections(history.document);
    expect(sections.map((s) => s.name), ['Closing', 'Opening']);
    expect(history.undoLabel, 'Move section');
  });

  testWidgets('a section never moves above the unsectioned run', (tester) async {
    final document = _marked(EditorDocument.fromJson(_deck()), 2, 'Closing');
    final history = await _pump(tester, document);
    await _rightClick(tester, find.text('Closing'));
    await tester.tap(find.text('Move section up'));
    await tester.pumpAndSettle();
    expect(history.canUndo, isFalse);
    expect(_order(history.document), ['el-0', 'el-1', 'el-2', 'el-3']);
  });

  testWidgets('move section down swaps with the following section', (tester) async {
    var document = EditorDocument.fromJson(_deck());
    document = _marked(document, 1, 'Middle');
    document = _marked(document, 3, 'Closing');
    final history = await _pump(tester, document);
    await _rightClick(tester, find.text('Middle'));
    await tester.tap(find.text('Move section down'));
    await tester.pumpAndSettle();
    expect(_order(history.document), ['el-0', 'el-3', 'el-1', 'el-2']);
    expect(deckSections(history.document).map((s) => s.name), [null, 'Closing', 'Middle']);
    // The last section has nothing below it.
    await _rightClick(tester, find.text('Middle'));
    await tester.tap(find.text('Move section down'));
    await tester.pumpAndSettle();
    expect(_order(history.document), ['el-0', 'el-3', 'el-1', 'el-2']);
  });

  testWidgets('removing a section merges its slides back into the run above', (tester) async {
    final document = _marked(EditorDocument.fromJson(_deck()), 2, 'Closing');
    final history = await _pump(tester, document);
    await _rightClick(tester, find.text('Closing'));
    await tester.tap(find.text('Remove section'));
    await tester.pumpAndSettle();
    expect(history.document.sceneMeta(2), isEmpty);
    expect(find.text('Closing'), findsNothing);
    expect(find.byType(OiReorderable), findsOneWidget);
  });

  testWidgets('double-tapping the header name renames the section inline', (tester) async {
    final document = _marked(EditorDocument.fromJson(_deck()), 2, 'Closing');
    final history = await _pump(tester, document);
    await tester.tap(find.text('Closing'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Closing'));
    await tester.pump();
    final field = find.byType(EditableText);
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Finale');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(history.document.sceneMeta(2)['section'], {'name': 'Finale'});
    expect(find.text('Finale'), findsOneWidget);
  });

  testWidgets('Start section here in the tile menu creates the section', (tester) async {
    final history = await _pump(tester, EditorDocument.fromJson(_deck()));
    await _rightClick(tester, find.text('3'));
    await tester.tap(find.text('Start section here'));
    await tester.pumpAndSettle();
    expect(history.document.sceneMeta(2)['section'], {'name': 'Section 1'});
    expect(find.text('Section 1'), findsOneWidget);
  });
}
