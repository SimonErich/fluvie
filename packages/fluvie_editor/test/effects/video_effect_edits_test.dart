// Editing effect keyframes on the video timeline: a track tap with the
// playhead inside the bar inserts a stop there, a diamond drags to a new
// frame as one undo step, and Delete removes the selected stop — at the
// two-stop minimum collapsing the parameter to a literal.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck({int stops = 2, List<Object?>? easings}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-clip',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
          'effects': [
            {
              'kind': 'vignette',
              'amount': switch (stops) {
                2 when easings == null => {
                  'values': [0, 0.9],
                  'positions': ['30f', '90f'],
                },
                2 => {
                  'values': [0, 1],
                  'positions': ['0f', '100f'],
                  'easings': easings,
                },
                _ => {
                  'values': [0, 0.5, 0.9],
                  'positions': ['0f', '60f', '120f'],
                },
              },
            },
          ],
        },
      ],
    },
  ],
};

Map<String, Object?> _param(EditorDocument document) =>
    (((document.elementJson('el-clip')!['effects']! as List)[0]! as Map)['amount']! as Map)
        .cast<String, Object?>();

final class _Harness {
  _Harness(this.container, this.history, this.transport);
  final ProviderContainer container;
  final DocumentHistory history;
  final SlideTransport transport;
}

Future<_Harness> _pump(WidgetTester tester, {int stops = 2, List<Object?>? easings}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck(stops: stops, easings: easings)));
  final transport = SlideTransport(fps: 30, length: 120);
  addTearDown(transport.dispose);
  final harness = _Harness(container, history, transport);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 640,
              child: VideoModePanel(
                document: history.document,
                transport: transport,
                onCommand: history.dispatch,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

/// The lanes origin: the timeline's top-left plus the labels column (140)
/// and the ruler strip (24). The panel zooms whole videos at 2 px/frame.
Offset _lanesOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 24);

/// Row 2 is the effect row: Scenes, the clip's row, then its vignette.
Offset _fxRow(WidgetTester tester, double x) => _lanesOrigin(tester) + Offset(x, 2 * 28 + 14);

Future<void> _drag(WidgetTester tester, Offset from, Offset by) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset(by.dx / 2, 0));
  await tester.pump();
  await gesture.moveBy(Offset(by.dx / 2, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('the effect row renders under its element', (tester) async {
    await _pump(tester);
    expect(find.text('vignette'), findsOneWidget);
  });

  testWidgets('a track tap with the playhead inside the bar inserts a stop there', (tester) async {
    final harness = await _pump(tester);
    harness.transport.seek(60);
    await tester.pump();

    await tester.tapAt(_fxRow(tester, 300));
    await tester.pump();

    expect(_param(harness.history.document)['values'], [0, 0.45, 0.9]);
    expect(_param(harness.history.document)['positions'], ['30f', '60f', '90f']);
    harness.history.undo();
    expect(_param(harness.history.document)['values'], hasLength(2));
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('dragging a diamond repositions its stop as one undo step', (tester) async {
    final harness = await _pump(tester, stops: 3);
    // The middle stop sits at frame 60 (px 120); drag it 30px right (15 frames).
    await _drag(tester, _fxRow(tester, 120), const Offset(30, 0));

    expect(_param(harness.history.document)['positions'], ['0f', '75f', '120f']);
    harness.history.undo();
    expect(_param(harness.history.document)['positions'], ['0f', '60f', '120f']);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('Delete removes the selected stop', (tester) async {
    final harness = await _pump(tester, stops: 3);
    await tester.tapAt(_fxRow(tester, 120));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(_param(harness.history.document)['values'], [0, 0.9]);
    harness.history.undo();
    expect(_param(harness.history.document)['values'], hasLength(3));
  });

  testWidgets('an insert under an overshooting easing writes the clamped boundary value', (
    tester,
  ) async {
    // easeOutBack reads above 1 late in the segment; the written stop must
    // face the same range a literal would, so it lands clamped, not refused.
    final harness = await _pump(tester, easings: ['back']);
    harness.transport.seek(90);
    await tester.pump();

    await tester.tapAt(_fxRow(tester, 300));
    await tester.pump();

    final values = (_param(harness.history.document)['values']! as List).cast<num>();
    expect(values, hasLength(3));
    expect(values[1], 1);
  });

  testWidgets('tapping an effect bar body selects its element and nothing crashes', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await tester.tapAt(_fxRow(tester, 100));
    await tester.pump();

    expect(harness.container.read(selectionProvider), {'el-clip'});
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('an edit clears the diamond selection, so Delete cannot hit a shifted stop', (
    tester,
  ) async {
    // Select the middle diamond, then insert a stop before it: every index
    // shifts, so the stale selection must not survive to the Delete.
    final harness = await _pump(tester, stops: 3);
    await tester.tapAt(_fxRow(tester, 120));
    await tester.pump();
    harness.transport.seek(30);
    await tester.pump();
    await tester.tapAt(_fxRow(tester, 300));
    await tester.pump();
    expect(_param(harness.history.document)['values'], hasLength(4));

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(_param(harness.history.document)['values'], hasLength(4));
  });

  testWidgets('at the two-stop minimum Delete collapses the parameter to a literal', (
    tester,
  ) async {
    final harness = await _pump(tester);
    // The first stop's diamond sits at frame 30 (px 60).
    await tester.tapAt(_fxRow(tester, 60));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    final effect =
        (((harness.history.document.elementJson('el-clip')!['effects']! as List)[0]!) as Map)
            .cast<String, Object?>();
    expect(effect['amount'], 0.9);
    harness.history.undo();
    expect(_param(harness.history.document)['values'], hasLength(2));
  });
}
