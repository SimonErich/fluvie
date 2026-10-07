// Dragging an effect out of the browser: onto an element on the canvas and
// onto a bar in the timeline. Both drops land the same AddEffectCommand the
// browser tap does, so the three gestures cannot drift.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _canvasDeck() => {
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
      ],
    },
  ],
};

Map<String, Object?> _timelineDeck() => {
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
        },
      ],
    },
  ],
};

/// A pointer-anchored source chip beside the drop surface.
Widget _chip() => const Draggable<EffectDragData>(
  data: EffectDragData({'kind': 'grain'}),
  dragAnchorStrategy: pointerDragAnchorStrategy,
  feedback: SizedBox.square(dimension: 4),
  child: SizedBox(
    key: Key('drag-source'),
    width: 40,
    height: 40,
    child: ColoredBox(color: Color(0xFF444455)),
  ),
);

Future<void> _dragTo(WidgetTester tester, Offset target) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(const Key('drag-source'))),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(2, 2));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('a drop on a canvas element adds the effect there', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final history = DocumentHistory(EditorDocument.fromJson(_canvasDeck()));
    final viewport = CanvasViewportController();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          title: 'test',
          theme: OiThemeData.dark(),
          home: ListenableBuilder(
            listenable: history,
            builder: (context, _) => Column(
              children: [
                _chip(),
                Center(
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
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final elementCenter =
        tester.getTopLeft(find.byType(EditorCanvas)) +
        viewport.toViewport(const Offset(320 * 0.25, 180 * 0.5));
    await _dragTo(tester, elementCenter);

    final effects = history.document.elementJson('el-left')!['effects']! as List;
    expect((effects.single! as Map)['kind'], 'grain');
    expect(container.read(selectionProvider), {'el-left'});
  });

  testWidgets('a drop past every element adds nothing', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final history = DocumentHistory(EditorDocument.fromJson(_canvasDeck()));
    final viewport = CanvasViewportController();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          title: 'test',
          theme: OiThemeData.dark(),
          home: Column(
            children: [
              _chip(),
              Center(
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
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final emptySpot =
        tester.getTopLeft(find.byType(EditorCanvas)) +
        viewport.toViewport(const Offset(320 * 0.75, 180 * 0.5));
    await _dragTo(tester, emptySpot);

    expect(history.document.elementJson('el-left')!.containsKey('effects'), isFalse);
    expect(history.canUndo, isFalse);
  });

  testWidgets('a drop on a timeline bar adds the effect on its element', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final history = DocumentHistory(EditorDocument.fromJson(_timelineDeck()));
    final transport = SlideTransport(fps: 30, length: 120);
    addTearDown(transport.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          title: 'test',
          theme: OiThemeData.dark(),
          home: ListenableBuilder(
            listenable: history,
            builder: (context, _) => Column(
              children: [
                _chip(),
                Align(
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
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The clip's bar: labels column 140 + ruler 24, row 1 (under Scenes),
    // frame 60 at 2 px per frame.
    final barPoint =
        tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140 + 120, 24 + 1 * 28 + 14);
    await _dragTo(tester, barPoint);

    final effects = history.document.elementJson('el-clip')!['effects']! as List;
    expect((effects.single! as Map)['kind'], 'grain');
  });
}
