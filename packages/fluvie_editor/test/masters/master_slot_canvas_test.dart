import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck({bool fillTitle = false}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'masters': {
    'base': {
      'children': [
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.25, 'w': 0.6, 'h': 0.3},
          'style': {'fontSize': 20},
        },
        {
          'type': 'Placeholder',
          'slot': 'media',
          'transform': {'x': 0.5, 'y': 0.75, 'w': 0.6, 'h': 0.3},
        },
      ],
    },
  },
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'master': 'base',
      if (fillTitle)
        'fills': {
          'title': {'id': 'el-fill', 'type': 'Text', 'text': 'Filled title'},
        },
      'children': <Object?>[],
    },
  ],
};

final class _FakeImporter implements MediaImporter {
  int picks = 0;

  @override
  Future<MediaPick?> pickMedia() async {
    picks++;
    return const MediaPick(source: {'kind': 'file', 'value': '/media/photo.png'}, isVideo: false);
  }
}

final class _Harness {
  _Harness(this.container, this.viewport, this.history);
  final ProviderContainer container;
  final CanvasViewportController viewport;
  final DocumentHistory history;
}

Future<_Harness> _pump(WidgetTester tester, {bool fillTitle = false}) async {
  final importer = _FakeImporter();
  final container = ProviderContainer(
    overrides: [mediaImporterProvider.overrideWithValue(importer)],
  );
  addTearDown(container.dispose);
  final viewport = CanvasViewportController();
  final history = DocumentHistory(EditorDocument.fromJson(_deck(fillTitle: fillTitle)));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => Center(
            child: SizedBox(
              width: 320,
              height: 180,
              child: EditorCanvas(
                document: history.document,
                slide: 0,
                viewportController: viewport,
                fitMargin: 0,
                interactive: true,
                onCommand: history.dispatch,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, viewport, history);
}

Offset _at(WidgetTester tester, CanvasViewportController viewport, double fx, double fy) =>
    tester.getTopLeft(find.byType(EditorCanvas)) + viewport.toViewport(Offset(320 * fx, 180 * fy));

void main() {
  testWidgets('an adopting slide badges its master and outlines unfilled slots', (tester) async {
    await _pump(tester);
    expect(find.byType(MasterSlotOverlay), findsOneWidget);
    expect(find.text('master: base'), findsOneWidget);
    // Both slots are unfilled: their names invite a click.
    expect(find.text('title'), findsOneWidget);
    expect(find.text('media'), findsOneWidget);
  });

  testWidgets('a filled slot loses its outline', (tester) async {
    await _pump(tester, fillTitle: true);
    expect(find.text('title'), findsNothing);
    expect(find.text('media'), findsOneWidget);
  });

  testWidgets('clicking a text slot types straight into a new fill', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness.viewport, 0.5, 0.25));
    await tester.pump();
    expect(find.byType(EditableText), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Typed in');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final document = harness.history.document;
    final fillId = document.masterSlots(0)[0].fillId;
    expect(fillId, isNotNull);
    expect(document.elementJson(fillId!)!['text'], 'Typed in');
    expect(document.fillSlotOf(fillId), 'title');
    // The new fill is selected and the whole fill was one undo step.
    expect(harness.container.read(selectionProvider), {fillId});
    harness.history.undo();
    expect(harness.history.document.masterSlots(0)[0].fillId, isNull);
  });

  testWidgets('abandoning the slot editor leaves the slot unfilled', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness.viewport, 0.5, 0.25));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.history.document.masterSlots(0)[0].fillId, isNull);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('clicking a media slot fills it through the importer', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness.viewport, 0.5, 0.75));
    await tester.pump();
    await tester.pump();
    final document = harness.history.document;
    final fillId = document.masterSlots(0)[1].fillId;
    expect(fillId, isNotNull);
    final fill = document.elementJson(fillId!)!;
    expect(fill['type'], 'Image');
    expect(fill['source'], {'kind': 'file', 'value': '/media/photo.png'});
    expect(fill.containsKey('transform'), isFalse, reason: 'the placeholder places it');
  });

  testWidgets('a filled slot selects like a normal element', (tester) async {
    final harness = await _pump(tester, fillTitle: true);
    await tester.tapAt(_at(tester, harness.viewport, 0.5, 0.25));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-fill'});
  });
}
