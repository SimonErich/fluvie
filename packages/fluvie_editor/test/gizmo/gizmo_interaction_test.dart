import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Box, LivePlayer, Placed;
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
          'id': 'el-left',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.25, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
        {
          'id': 'el-right',
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.75, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.viewport, this.history);

  final ProviderContainer container;
  final CanvasViewportController viewport;
  final DocumentHistory history;

  Map<String, Object?>? transformOf(String id) =>
      history.document.elementJson(id)?['transform'] as Map<String, Object?>?;
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
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

/// The global point over the canvas-pixel position ([x], [y]).
Offset _at(WidgetTester tester, _Harness harness, double x, double y) =>
    tester.getTopLeft(find.byType(EditorCanvas)) + harness.viewport.toViewport(Offset(x, y));

Future<void> _drag(
  WidgetTester tester,
  _Harness harness,
  Offset fromCanvas,
  Offset toCanvas,
) async {
  final gesture = await tester.startGesture(
    _at(tester, harness, fromCanvas.dx, fromCanvas.dy),
  );
  await tester.pump();
  await gesture.moveTo(_at(tester, harness, toCanvas.dx, toCanvas.dy));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  // el-left: transform (x .25, y .5, w .3, h .4) on 320x180 lays out at
  // LTWH(32, 54, 96, 72) with center (80, 90).

  testWidgets('dragging a selected element moves it in one undo step', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.pump();

    await _drag(tester, harness, const Offset(80, 90), const Offset(160, 90));
    final transform = harness.transformOf('el-left')!;
    expect(transform['x'], closeTo(0.5, 1e-9));
    expect(transform['y'], closeTo(0.5, 1e-9));
    expect(transform['w'], closeTo(0.3, 1e-9));

    expect(harness.history.canUndo, isTrue);
    harness.history.undo();
    expect(harness.transformOf('el-left')!['x'], closeTo(0.25, 1e-9));
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('dragging an unselected element selects it and moves it', (tester) async {
    final harness = await _pump(tester);
    await _drag(tester, harness, const Offset(80, 90), const Offset(96, 108));
    expect(harness.container.read(selectionProvider), {'el-left'});
    expect(harness.transformOf('el-left')!['x'], closeTo(0.3, 1e-9));
    expect(harness.transformOf('el-left')!['y'], closeTo(0.6, 1e-9));
  });

  testWidgets('a multi-selection drags as one group, one undo step', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(_at(tester, harness, 240, 90));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    await _drag(tester, harness, const Offset(80, 90), const Offset(80, 54));
    expect(harness.transformOf('el-left')!['y'], closeTo(0.3, 1e-9));
    expect(harness.transformOf('el-right')!['y'], closeTo(0.3, 1e-9));
    harness.history.undo();
    expect(harness.transformOf('el-left')!['y'], closeTo(0.5, 1e-9));
    expect(harness.transformOf('el-right')!['y'], closeTo(0.5, 1e-9));
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('a corner handle resizes; Shift keeps the aspect', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.pump();

    // bottomRight corner sits at (128, 126); the opposite corner stays.
    await _drag(tester, harness, const Offset(128, 126), const Offset(160, 140));
    var transform = harness.transformOf('el-left')!;
    expect(transform['w'], closeTo(128 / 320, 1e-9));
    expect(transform['h'], closeTo(86 / 180, 1e-9));

    harness.history.undo();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _drag(tester, harness, const Offset(128, 126), const Offset(160, 140));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    transform = harness.transformOf('el-left')!;
    expect(transform['w'], closeTo(0.4, 1e-9));
    expect(transform['h'], closeTo(96 / 180, 1e-9));
  });

  testWidgets('Alt resizes around the center', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await _drag(tester, harness, const Offset(128, 90), const Offset(160, 90));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    final transform = harness.transformOf('el-left')!;
    expect(transform['x'], closeTo(0.25, 1e-9));
    expect(transform['w'], closeTo(0.5, 1e-9));
    expect(transform['h'], closeTo(0.4, 1e-9));
  });

  testWidgets('the rotation zone rotates, snapping with Shift', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _drag(tester, harness, const Offset(140, 138), const Offset(80, 200));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    final transform = harness.transformOf('el-left')!;
    expect(transform['rotation'], 45);
    expect(transform['x'], closeTo(0.25, 1e-9));
    expect(transform['w'], closeTo(0.3, 1e-9));
  });

  testWidgets('arrow keys nudge, Shift steps larger, and a run is one undo', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(harness.transformOf('el-left')!['x'], closeTo(0.25 + 1 / 320, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(harness.transformOf('el-left')!['y'], closeTo(0.5 + 1 / 180, 1e-9));

    harness.history.undo();
    await tester.pump();
    expect(harness.transformOf('el-left')!['x'], closeTo(0.25, 1e-9));
    expect(harness.transformOf('el-left')!['y'], closeTo(0.5, 1e-9));
    expect(harness.history.canUndo, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(harness.transformOf('el-left')!['x'], closeTo(0.25 - 10 / 320, 1e-9));
  });

  testWidgets('a drag never touches the document until release', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.pump();
    final playerBefore = tester.widget<LivePlayer>(find.byType(LivePlayer));

    final gesture = await tester.startGesture(_at(tester, harness, 80, 90));
    await tester.pump();
    await gesture.moveTo(_at(tester, harness, 160, 90));
    await tester.pump();

    // Mid-drag: the document still holds the original transform...
    expect(harness.transformOf('el-left')!['x'], closeTo(0.25, 1e-9));
    expect(harness.history.canUndo, isFalse);
    // ...the slide was not re-derived (the exact same player subtree)...
    final playerDuring = tester.widget<LivePlayer>(find.byType(LivePlayer));
    expect(identical(playerDuring.child, playerBefore.child), isTrue);
    // ...and yet the element already renders at its dragged position.
    final placed = find.byWidgetPredicate(
      (widget) => widget is Placed && widget.id == 'el-left',
    );
    final box = find.descendant(of: placed, matching: find.byType(Box));
    expect(tester.getCenter(box), _at(tester, harness, 160, 90));

    await gesture.up();
    await tester.pump();
    expect(harness.transformOf('el-left')!['x'], closeTo(0.5, 1e-9));
    expect(harness.history.canUndo, isTrue);
  });

  testWidgets('a press without movement never commits a step', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.pump();
    final gesture = await tester.startGesture(_at(tester, harness, 80, 90));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('Escape cancels a drag without committing', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.pump();
    final gesture = await tester.startGesture(_at(tester, harness, 80, 90));
    await tester.pump();
    await gesture.moveTo(_at(tester, harness, 160, 90));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(harness.transformOf('el-left')!['x'], closeTo(0.25, 1e-9));
    expect(harness.history.canUndo, isFalse);
    // The selection survives a cancelled drag.
    expect(harness.container.read(selectionProvider), {'el-left'});
  });

  testWidgets('marquee still works from empty canvas with a selection', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_at(tester, harness, 80, 90));
    await tester.pump();
    await _drag(tester, harness, const Offset(10, 4), const Offset(310, 176));
    expect(harness.container.read(selectionProvider), {'el-left', 'el-right'});
    // A marquee never writes the document.
    expect(harness.history.canUndo, isFalse);
  });
}
