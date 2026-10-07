import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Placed;
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
      'background': {'kind': 'color', 'color': '#14141C'},
      'children': [
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Hello',
          'style': {'color': '#F9FAFB', 'fontSize': 24},
          'transform': {'x': 0.5, 'y': 0.2, 'w': 0.5, 'h': 0.2},
        },
      ],
    },
  ],
};

final class _FakeImporter implements MediaImporter {
  _FakeImporter(this.pick);
  final MediaPick? pick;
  int calls = 0;

  @override
  Future<MediaPick?> pickMedia() async {
    calls++;
    return pick;
  }
}

final class _Harness {
  _Harness(this.container, this.viewport, this.history);
  final ProviderContainer container;
  final CanvasViewportController viewport;
  final DocumentHistory history;

  ToolState get tool => container.read(toolProvider);
  EditorDocument get document => history.document;
}

Future<_Harness> _pump(WidgetTester tester, {MediaImporter? importer}) async {
  final container = ProviderContainer(
    overrides: [if (importer != null) mediaImporterProvider.overrideWithValue(importer)],
  );
  addTearDown(container.dispose);
  final viewport = CanvasViewportController();
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
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

Offset _at(WidgetTester tester, _Harness harness, double x, double y) =>
    tester.getTopLeft(find.byType(EditorCanvas)) + harness.viewport.toViewport(Offset(x, y));

Future<void> _drag(WidgetTester tester, _Harness harness, Offset from, Offset to) async {
  final gesture = await tester.startGesture(_at(tester, harness, from.dx, from.dy));
  await tester.pump();
  await gesture.moveTo(_at(tester, harness, to.dx, to.dy));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('R then a drag places a rect Shape, selects it, resets the tool', (tester) async {
    final harness = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(harness.tool.tool, EditorTool.shape);

    await _drag(tester, harness, const Offset(40, 60), const Offset(160, 120));
    final ids = harness.document.elementIdsInScene(0);
    expect(ids, hasLength(2));
    final placed = harness.document.elementJson(ids.last)!;
    expect(placed['type'], 'Shape');
    expect(placed['kind'], 'rect');
    expect(placed['rect'], {'x': 40.0, 'y': 60.0, 'w': 120.0, 'h': 60.0});
    expect(harness.container.read(selectionProvider), {ids.last});
    expect(harness.tool.tool, EditorTool.select);
    expect(harness.history.canUndo, isTrue);
  });

  testWidgets('Shift constrains a rect drag to a square', (tester) async {
    final harness = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _drag(tester, harness, const Offset(40, 40), const Offset(140, 80));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    final placed = harness.document.elementJson(harness.document.elementIdsInScene(0).last)!;
    final rect = placed['rect']! as Map<String, Object?>;
    expect(rect['w'], rect['h']);
  });

  testWidgets('the text tool click drops into inline editing and commits', (tester) async {
    final harness = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    await tester.tapAt(_at(tester, harness, 80, 120));
    await tester.pump();

    final ids = harness.document.elementIdsInScene(0);
    expect(ids, hasLength(2));
    expect(find.byType(EditableText), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'Welcome!');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(EditableText), findsNothing);
    expect(harness.document.elementJson(ids.last)!['text'], 'Welcome!');
  });

  testWidgets('double-clicking existing text re-enters editing', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 160, 36));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(_at(tester, harness, 160, 36));
    await tester.pump();
    expect(find.byType(EditableText), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Hello');

    await tester.enterText(find.byType(EditableText), 'Changed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.document.elementJson('el-title')!['text'], 'Changed');
  });

  testWidgets('the media tool asks the importer and inserts the pick', (tester) async {
    final importer = _FakeImporter(
      const MediaPick(source: {'kind': 'file', 'value': '/tmp/photo.png'}, isVideo: false),
    );
    final harness = await _pump(tester, importer: importer);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pumpAndSettle();

    expect(importer.calls, 1);
    final ids = harness.document.elementIdsInScene(0);
    expect(ids, hasLength(2));
    final placed = harness.document.elementJson(ids.last)!;
    expect(placed['type'], 'Image');
    expect(placed['source'], {'kind': 'file', 'value': '/tmp/photo.png'});
    expect(harness.tool.tool, EditorTool.select);
  });

  testWidgets('a named import records a store entry before inserting', (tester) async {
    final importer = _FakeImporter(
      const MediaPick(
        source: {'kind': 'file', 'value': '/tmp/photo.png'},
        isVideo: false,
        name: 'photo.png',
        sizeBytes: 12,
      ),
    );
    final harness = await _pump(tester, importer: importer);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pumpAndSettle();

    final entry = harness.document.mediaEntries.single;
    expect(entry.name, 'photo.png');
    expect(entry.kind, MediaStoreKind.image);
    expect(entry.sizeBytes, 12);
    expect(harness.document.elementIdsInScene(0), hasLength(2));

    // A second import of the same source records nothing new.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pumpAndSettle();
    expect(harness.document.mediaEntries, hasLength(1));
    expect(harness.document.elementIdsInScene(0), hasLength(3));
  });

  testWidgets('an audio import lands in the store only, never on the canvas', (tester) async {
    final importer = _FakeImporter(
      const MediaPick(
        source: {'kind': 'file', 'value': '/tmp/bed.mp3'},
        isVideo: false,
        isAudio: true,
        name: 'bed.mp3',
      ),
    );
    final harness = await _pump(tester, importer: importer);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pumpAndSettle();

    expect(harness.document.mediaEntries.single.kind, MediaStoreKind.audio);
    expect(harness.document.elementIdsInScene(0), hasLength(1));
    expect(harness.tool.tool, EditorTool.select);
  });

  testWidgets('a cancelled media pick just returns to select', (tester) async {
    final importer = _FakeImporter(null);
    final harness = await _pump(tester, importer: importer);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pumpAndSettle();
    expect(importer.calls, 1);
    expect(harness.document.elementIdsInScene(0), hasLength(1));
    expect(harness.tool.tool, EditorTool.select);
  });

  testWidgets('the hand tool pans instead of selecting', (tester) async {
    final harness = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    final before = harness.viewport.offset;
    await _drag(tester, harness, const Offset(160, 90), const Offset(120, 60));
    expect(harness.viewport.offset, isNot(before));
    expect(harness.container.read(selectionProvider), isEmpty);
    expect(harness.document.elementIdsInScene(0), hasLength(1));
  });

  testWidgets('Escape returns any tool to select', (tester) async {
    final harness = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    expect(harness.tool.tool, EditorTool.text);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(harness.tool.tool, EditorTool.select);
  });
  untouchableSuite();
}

// Locked and hidden elements are inert on the canvas.
void untouchableSuite() {
  testWidgets('a locked element cannot be clicked or dragged', (tester) async {
    final harness = await _pump(tester);
    harness.history.dispatch(
      const SetElementMetaCommand(id: 'el-title', meta: {'locked': true}),
    );
    await tester.pump();
    await tester.tapAt(_at(tester, harness, 160, 36));
    await tester.pump();
    expect(harness.container.read(selectionProvider), isEmpty);

    await _drag(tester, harness, const Offset(160, 36), const Offset(240, 36));
    final transform = harness.document.elementJson('el-title')!['transform']! as Map;
    expect(transform['x'], closeTo(0.5, 1e-9));
  });

  testWidgets('a hidden element (spec visible: false) leaves the preview', (tester) async {
    final harness = await _pump(tester);
    harness.history.dispatch(
      const SetElementsVisibleCommand(ids: ['el-title'], visible: false),
    );
    await tester.pump();
    final placed = find.byWidgetPredicate(
      (widget) => widget is Placed && widget.id == 'el-title',
    );
    expect(placed, findsNothing);

    await tester.tapAt(_at(tester, harness, 160, 36));
    await tester.pump();
    expect(harness.container.read(selectionProvider), isEmpty, reason: 'hidden skips hits');
  });
  polishSuite();
}

// The floating toolbar, the delete key, and the empty-slide invitation.
void polishSuite() {
  testWidgets('selecting shows the floating toolbar; delete clears it', (tester) async {
    final harness = await _pump(tester);
    expect(find.byType(SelectionToolbar), findsNothing);
    await tester.tapAt(_at(tester, harness, 160, 36));
    await tester.pump();
    expect(find.byType(SelectionToolbar), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Delete element'));
    await tester.pump();
    expect(harness.document.elementIdsInScene(0), isEmpty);
    expect(harness.container.read(selectionProvider), isEmpty);
    expect(find.byType(SelectionToolbar), findsNothing);
  });

  testWidgets('Backspace deletes the selection undoably', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 160, 36));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(harness.document.elementIdsInScene(0), isEmpty);
    harness.history.undo();
    expect(harness.document.elementIdsInScene(0), ['el-title']);
  });

  testWidgets('an empty slide invites an action', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 160, 36));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(find.textContaining('An empty slide'), findsOneWidget);
  });
}
