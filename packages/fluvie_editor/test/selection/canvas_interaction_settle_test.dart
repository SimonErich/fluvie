import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/selection/selection_chrome.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// A two-scene deck whose scene 1 arrives on an overlapping `slide` enter:
/// its span starts at 45, its blend ends (and it settles) at 60.
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
          'id': 'el-a',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
      ],
    },
    {
      'duration': '60f',
      'layout': 'canvas',
      'enter': {'kind': 'slide', 'duration': '15f'},
      'background': {'kind': 'color', 'color': '#101820'},
      'children': [
        {
          'id': 'el-box',
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
      ],
    },
  ],
};

Future<void> _pump(
  WidgetTester tester, {
  required ProviderContainer container,
  required EditorDocument document,
  required SlideTransport transport,
  required CanvasViewportController viewport,
  required int settleFrame,
  required List<EditorCommand> commands,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 320,
            height: 180,
            child: EditorCanvas(
              document: document,
              slide: 1,
              viewportController: viewport,
              fitMargin: 0,
              interactive: true,
              wholeDocument: true,
              transport: transport,
              settleFrame: settleFrame,
              onCommand: commands.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The viewport point over canvas fraction ([fx], [fy]).
Offset _at(WidgetTester tester, CanvasViewportController viewport, double fx, double fy) =>
    tester.getTopLeft(find.byType(EditorCanvas)) + viewport.toViewport(Offset(320 * fx, 180 * fy));

/// A body drag over the scene-1 element at the canvas center.
Future<void> _dragElement(WidgetTester tester, CanvasViewportController viewport) async {
  final from = _at(tester, viewport, 0.5, 0.5);
  final gesture = await tester.startGesture(from);
  await gesture.moveTo(from + const Offset(30, 0));
  await tester.pump();
  await gesture.moveTo(from + const Offset(60, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('video mode: a mid-transition scene is inert, its settled frame edits', (
    tester,
  ) async {
    final commands = <EditorCommand>[];
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final document = EditorDocument.fromJson(_deck());
    final timebase = VideoTimebase.of(document);
    final transport = SlideTransport(fps: 30, length: timebase.totalFrames);
    addTearDown(transport.dispose);
    final viewport = CanvasViewportController();

    // Scene 1 settled (its blend ended at 60): dragging the element commits.
    transport.seek(70);
    await _pump(
      tester,
      container: container,
      document: document,
      transport: transport,
      viewport: viewport,
      settleFrame: timebase.settleFrameOf(1),
      commands: commands,
    );
    expect(find.text('Scrub to the settled frame to edit'), findsNothing);
    await _dragElement(tester, viewport);
    expect(commands, isNotEmpty);

    commands.clear();
    container.read(selectionProvider.notifier).clear();

    // Scene 1 mid-transition (span start 45, blend still running): the input
    // layer is inert — no selection, no gizmo drag, no marquee, no command,
    // because the geometry no longer matches the displaced render.
    transport.seek(45);
    await tester.pump();
    expect(find.text('Scrub to the settled frame to edit'), findsOneWidget);
    await _dragElement(tester, viewport);
    expect(commands, isEmpty);
    expect(container.read(selectionProvider), isEmpty);
    expect(find.byType(MarqueeOverlay), findsNothing);

    // Back to a settled frame: editing works again.
    transport.seek(70);
    await tester.pump();
    expect(find.text('Scrub to the settled frame to edit'), findsNothing);
    await _dragElement(tester, viewport);
    expect(commands, isNotEmpty);
  });

  testWidgets('a swapped transport re-wires the settle gate', (tester) async {
    final commands = <EditorCommand>[];
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final document = EditorDocument.fromJson(_deck());
    final timebase = VideoTimebase.of(document);
    final settle = timebase.settleFrameOf(1);
    final viewport = CanvasViewportController();

    // The first clock parks mid-transition: the gate shows.
    final first = SlideTransport(fps: 30, length: timebase.totalFrames)..seek(45);
    addTearDown(first.dispose);
    await _pump(
      tester,
      container: container,
      document: document,
      transport: first,
      viewport: viewport,
      settleFrame: settle,
      commands: commands,
    );
    expect(find.text('Scrub to the settled frame to edit'), findsOneWidget);

    // Swapping in a settled clock lifts the gate and re-points the listener.
    final second = SlideTransport(fps: 30, length: timebase.totalFrames)..seek(70);
    addTearDown(second.dispose);
    await _pump(
      tester,
      container: container,
      document: document,
      transport: second,
      viewport: viewport,
      settleFrame: settle,
      commands: commands,
    );
    expect(find.text('Scrub to the settled frame to edit'), findsNothing);

    // The new clock now drives the gate.
    second.seek(45);
    await tester.pump();
    expect(find.text('Scrub to the settled frame to edit'), findsOneWidget);
  });
}
