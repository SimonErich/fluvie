import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show SlidePreviewService;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiReorderable, OiThemeData;

Map<String, Object?> _deck({int scenes = 2}) => {
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

/// Renders 4x4 stand-ins and counts calls per slide, so tests can pin
/// cache invalidation by observing the re-render.
final class _CountingRenderer {
  final Map<int, int> renders = {};

  Future<ui.Image> call(int slide) async {
    renders[slide] = (renders[slide] ?? 0) + 1;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 4, 4),
      ui.Paint()..color = const ui.Color(0xFF123456),
    );
    return recorder.endRecording().toImage(4, 4);
  }
}

final class _Harness {
  _Harness(this.service, this.history, this.renderer);
  final SlidePreviewService service;
  final DocumentHistory history;
  final _CountingRenderer renderer;
  final List<EditorCommand> commands = [];
  final List<int> selected = [];
}

Future<_Harness> _pump(WidgetTester tester, {int scenes = 2, DocumentHistory? withHistory}) async {
  final renderer = _CountingRenderer();
  final service = SlidePreviewService(renderSlide: renderer.call);
  addTearDown(service.dispose);
  final history = withHistory ?? DocumentHistory(EditorDocument.fromJson(_deck(scenes: scenes)));
  final harness = _Harness(service, history, renderer);
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
            onSelect: harness.selected.add,
            onCommand: (command) {
              harness.commands.add(command);
              history.dispatch(command);
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

void main() {
  testWidgets('the strip shows a tile per slide and requests previews', (tester) async {
    final harness = await _pump(tester);
    // Position lives in the top bar alone; the strip numbers its tiles.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(harness.service.peek(0), isNotNull, reason: 'tiles request lazily');
  });

  testWidgets('add, duplicate, and delete go through the command layer', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Add slide'));
    await tester.pump();
    expect(harness.history.document.sceneCount, 3);

    await tester.tap(find.bySemanticsLabel('Duplicate slide'));
    await tester.pump();
    expect(harness.history.document.sceneCount, 4);
    // The duplicate landed right after the current slide with fresh ids.
    expect(harness.history.document.elementIdsInScene(1), isNot(['el-0']));
    expect(
      harness.history.document.elementJson(
        harness.history.document.elementIdsInScene(1).single,
      )!['text'],
      'slide 0',
    );

    await tester.tap(find.bySemanticsLabel('Delete slide'));
    await tester.pump();
    expect(harness.history.document.sceneCount, 3);
    // Every action was a command, so it all undoes.
    expect(harness.commands, hasLength(3));
    harness.history
      ..undo()
      ..undo()
      ..undo();
    expect(harness.history.document.sceneCount, 2);
  });

  testWidgets('the last slide cannot be deleted', (tester) async {
    final harness = await _pump(tester, scenes: 1);
    await tester.tap(find.bySemanticsLabel('Delete slide'), warnIfMissed: false);
    await tester.pump();
    expect(harness.history.document.sceneCount, 1);
    expect(harness.commands, isEmpty);
  });

  testWidgets('an edit invalidates the thumbnail cache', (tester) async {
    final harness = await _pump(tester);
    await tester.pumpAndSettle();
    expect(harness.service.peek(0), isNotNull);
    final before = harness.renderer.renders[0] ?? 0;

    harness.history.dispatch(
      const ReplaceElementCommand(id: 'el-0', element: {'type': 'Text', 'text': 'edited'}),
    );
    await tester.pumpAndSettle();
    expect(
      harness.renderer.renders[0],
      greaterThan(before),
      reason: 'the edit dropped the cache, so the tile re-rendered',
    );
  });

  testWidgets('a theme edit invalidates the thumbnail cache too', (tester) async {
    final harness = await _pump(tester);
    await tester.pumpAndSettle();
    final before = harness.renderer.renders[0] ?? 0;

    harness.history.dispatch(
      const SetThemeCommand(
        theme: {
          'palette': {'accent': '#FF0000'},
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
      harness.renderer.renders[0],
      greaterThan(before),
      reason: 'video-level content counts into the preview key',
    );
  });

  testWidgets('dragging tiles reorders scenes through the command layer', (tester) async {
    final harness = await _pump(tester, scenes: 3);
    tester.widget<OiReorderable>(find.byType(OiReorderable)).onReorder(0, 2);
    await tester.pump();
    expect(harness.commands.single, isA<ReorderSceneCommand>());
    final reorder = harness.commands.single as ReorderSceneCommand;
    expect(reorder.from, 0);
    expect(reorder.to, 1);
  });

  testWidgets('tapping a tile selects its slide', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.text('2'));
    expect(harness.selected, [1]);
  });
}
