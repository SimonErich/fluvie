import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// One keyframes animation over frames 0..30 — at the default zoom (4
/// px/frame) its bar covers lane px 0..120 with stops at px 0, 60, 120.
Map<String, Object?> _deck({int stops = 3, int leadingScenes = 0}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    for (var i = 0; i < leadingScenes; i++)
      {
        'duration': '120f',
        'children': [
          {'id': 'el-filler-$i', 'type': 'Box', 'width': 10, 'height': 10},
        ],
      },
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-k',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'animate': [
            {
              'keyframes': [
                {'opacity': 0},
                if (stops == 3) {'x': 0.5},
                <String, Object?>{},
              ],
              'duration': '30f',
            },
          ],
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

Future<_Harness> _pump(WidgetTester tester, {int stops = 3, int leadingScenes = 0}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final harness = _Harness(
    container,
    DocumentHistory(EditorDocument.fromJson(_deck(stops: stops, leadingScenes: leadingScenes))),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: harness.history,
          builder: (context, _) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 640,
              child: TimelinePanel(
                document: harness.history.document,
                slide: leadingScenes,
                onCommand: harness.history.dispatch,
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

Map<String, Object?> _animation(EditorDocument document) =>
    ((document.elementJson('el-k')!['animate']! as List).first! as Map).cast<String, Object?>();

/// The lanes origin: the panel's top-left plus the labels column (140) and
/// the header plus ruler strip.
Offset _lanesOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 24);

Offset _rulerAt(WidgetTester tester, double dx) =>
    tester.getTopLeft(find.byType(TrackTimeline)) + Offset(140 + dx, 12);

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
  testWidgets('clicking the track at the playhead inserts an interpolated stop', (tester) async {
    final harness = await _pump(tester);
    // Park the playhead at frame 20, then click the row's empty space.
    await tester.tapAt(_rulerAt(tester, 80));
    await tester.pump();
    await tester.tapAt(_lanesOrigin(tester) + const Offset(300, 14));
    await tester.pump();
    final animation = _animation(harness.history.document);
    final stops = animation['keyframes']! as List;
    expect(stops, hasLength(4));
    // Between {x: 0.5}@15f and {}@30f at 20f: one third of the way back to 0.
    expect((stops[2]! as Map)['x'], closeTo(1 / 3, 1e-9));
    expect(animation['positions'], ['0f', '15f', '20f', '30f']);
    // One undo step restores the untouched form.
    harness.history.undo();
    expect(_animation(harness.history.document)['keyframes'], hasLength(3));
    expect(_animation(harness.history.document).containsKey('positions'), isFalse);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('with the playhead outside the bar a track tap still scrubs', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_rulerAt(tester, 200));
    await tester.pump();
    await tester.tapAt(_lanesOrigin(tester) + const Offset(300, 14));
    await tester.pump();
    expect(_animation(harness.history.document)['keyframes'], hasLength(3));
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('dragging a diamond writes the minted positions as one undo step', (tester) async {
    final harness = await _pump(tester);
    // The middle stop sits at frame 15 (px 60); drag it 20px right (5 frames).
    await _drag(tester, _lanesOrigin(tester) + const Offset(60, 14), const Offset(20, 0));
    final animation = _animation(harness.history.document);
    expect(animation['positions'], ['0f', '20f', '30f']);
    harness.history.undo();
    expect(_animation(harness.history.document).containsKey('positions'), isFalse);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('tapping a diamond selects its element and keyframe', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_lanesOrigin(tester) + const Offset(60, 14));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-k'});
    expect(
      harness.container.read(keyframeSelectionProvider),
      const SelectedKeyframe(elementId: 'el-k', animation: 0, stop: 1),
    );
  });

  testWidgets('Delete removes the selected stop; a two-stop bar loses the animation', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await tester.tapAt(_lanesOrigin(tester) + const Offset(60, 14));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(_animation(harness.history.document)['keyframes'], hasLength(2));
    expect(harness.container.read(keyframeSelectionProvider), isNull);
    harness.history.undo();
    expect(_animation(harness.history.document)['keyframes'], hasLength(3));

    // Down to two stops, deleting one removes the whole animation.
    final two = await _pump(tester, stops: 2);
    await tester.tapAt(_lanesOrigin(tester) + const Offset(120, 14));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(two.history.document.elementJson('el-k')!.containsKey('animate'), isFalse);
    two.history.undo();
    expect(two.history.document.elementJson('el-k')!['animate'], hasLength(1));
  });

  testWidgets('a bar tap clears the keyframe selection', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_lanesOrigin(tester) + const Offset(60, 14));
    await tester.pump();
    expect(harness.container.read(keyframeSelectionProvider), isNotNull);
    await tester.tapAt(_lanesOrigin(tester) + const Offset(40, 14));
    await tester.pump();
    expect(harness.container.read(keyframeSelectionProvider), isNull);
  });

  testWidgets('selecting another element elsewhere clears the keyframe selection', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_lanesOrigin(tester) + const Offset(60, 14));
    await tester.pump();
    expect(harness.container.read(keyframeSelectionProvider), isNotNull);
    harness.container.read(selectionProvider.notifier).clear();
    await tester.pump();
    expect(harness.container.read(keyframeSelectionProvider), isNull);
  });

  testWidgets('edits in a later scene still write scene-relative frames', (tester) async {
    // The slide starts at absolute frame 120; every written value must stay
    // bar- or trigger-relative (the absolute-times deck constraint).
    final harness = await _pump(tester, leadingScenes: 1);
    await _drag(tester, _lanesOrigin(tester) + const Offset(60, 14), const Offset(20, 0));
    expect(_animation(harness.history.document)['positions'], ['0f', '20f', '30f']);
    // A bar-body drag retimes by the same law: delay in frames, not absolute.
    await _drag(tester, _lanesOrigin(tester) + const Offset(30, 14), const Offset(40, 0));
    expect(_animation(harness.history.document)['delay'], '10f');
  });

  testWidgets('trimming a keyframes bar rescales its authored positions', (tester) async {
    final harness = await _pump(tester);
    // Mint positions first by moving the middle stop to frame 20.
    await _drag(tester, _lanesOrigin(tester) + const Offset(60, 14), const Offset(20, 0));
    expect(_animation(harness.history.document)['positions'], ['0f', '20f', '30f']);
    // Trim the right edge from frame 30 to frame 15: positions halve.
    await _drag(tester, _lanesOrigin(tester) + const Offset(119, 14), const Offset(-60, 0));
    final animation = _animation(harness.history.document);
    expect(animation['duration'], '15f');
    expect(animation['positions'], ['0f', '10f', '15f']);
  });
}
