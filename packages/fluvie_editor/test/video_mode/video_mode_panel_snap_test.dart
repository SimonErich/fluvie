// Snapping on the video timeline. A drag catches on the cuts and edges the
// author can see, one modifier lets it through, and a guide says what caught
// it — so a bar that lands on a boundary looks like it meant to.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// Two scenes, 120 and 90 frames, so the cut sits at frame 120. The clip in
/// scene 1 is windowed 10..50, which is absolute 130..170 and, at the panel's
/// 2 px/frame, lane pixels 260..340 on row 1.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        {
          'id': 'el-clip',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/broll.mp4'},
          'show': {'from': '10f', 'to': '50f'},
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.history, this.transport);
  final ProviderContainer container;
  final DocumentHistory history;
  final SlideTransport transport;
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  final transport = SlideTransport(fps: 30, length: 210);
  addTearDown(transport.dispose);
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
  return _Harness(container, history, transport);
}

/// The lanes origin: the timeline's top-left plus the labels column (140)
/// and the ruler strip (24). The panel zooms whole videos at 2 px/frame.
Offset _row(WidgetTester tester, int row, double x) =>
    tester.getTopLeft(find.byType(TrackTimeline)) +
    const Offset(140, 24) +
    Offset(x, row * 28 + 14);

Future<TestGesture> _dragTo(WidgetTester tester, Offset from, double dx) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset(dx / 2, 0));
  await tester.pump();
  await gesture.moveBy(Offset(dx / 2, 0));
  await tester.pump();
  return gesture;
}

Future<void> _drag(WidgetTester tester, Offset from, double dx) async {
  await (await _dragTo(tester, from, dx)).up();
  await tester.pump();
}

double? _guide(WidgetTester tester) =>
    tester.widget<TrackTimeline>(find.byType(TrackTimeline)).snapFrame;

Map<String, Object?> _show(_Harness harness) =>
    harness.history.document.elementJson('el-clip')!['show']! as Map<String, Object?>;

void main() {
  group('a moved bar', () {
    testWidgets('catches on the scene boundary it was dragged near', (tester) async {
      // -12 px is -6 frames, landing the start on 124: four frames short of
      // the cut, and inside the eight-pixel catch.
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 1, 300), -12);

      expect(_show(harness), {'from': '0f', 'to': '40f'});
    });

    testWidgets('is left alone when the drag ends nowhere near a candidate', (tester) async {
      // +40 px is +20 frames: absolute 150..190, thirty frames off the cut
      // behind it and twenty off the video's end ahead.
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 1, 300), 40);

      expect(_show(harness), {'from': '30f', 'to': '70f'});
    });

    testWidgets('catches on its trailing edge as well', (tester) async {
      // +78 px is +39 frames, putting the *end* on 209 — one frame short of
      // where the video ends. The bar moves so the end lands, not the start.
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 1, 300), 78);

      expect(_show(harness), {'from': '50f', 'to': '90f'});
    });
  });

  group('the guide', () {
    testWidgets('names the frame that caught the drag, and clears on release', (tester) async {
      await _pump(tester);

      final gesture = await _dragTo(tester, _row(tester, 1, 300), -12);
      expect(_guide(tester), 120);

      await gesture.up();
      await tester.pump();
      expect(_guide(tester), isNull, reason: 'a guide outlives no drag');
    });

    testWidgets('stays away when nothing caught the drag', (tester) async {
      await _pump(tester);

      final gesture = await _dragTo(tester, _row(tester, 1, 300), 40);
      expect(_guide(tester), isNull);

      await gesture.up();
      await tester.pump();
    });
  });

  group('letting a drag through', () {
    testWidgets('Ctrl bypasses the catch for one gesture', (tester) async {
      // The same modifier the canvas uses: one key means one thing.
      final harness = await _pump(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _drag(tester, _row(tester, 1, 300), -12);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(_show(harness), {'from': '4f', 'to': '44f'});
    });

    testWidgets('turning snapping off turns it off here too', (tester) async {
      // The timeline reads the same preference as the canvas rather than
      // owning a second switch that can disagree with the first.
      final harness = await _pump(tester);
      harness.container.read(snapPreferencesProvider.notifier).toggleSnapping();

      await _drag(tester, _row(tester, 1, 300), -12);

      expect(_show(harness), {'from': '4f', 'to': '44f'});
    });
  });

  group('a trimmed edge', () {
    testWidgets('catches on the boundary', (tester) async {
      // Grab the clip's leading edge at px 260 and pull it left six frames.
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 1, 261), -12);

      expect(_show(harness), {'from': '0f', 'to': '50f'});
    });

    testWidgets('never drags the edge the pointer is not on', (tester) async {
      // Trimming the tail must leave the head exactly where it was, however
      // close the head happens to sit to a candidate.
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 1, 339), -20);

      expect(_show(harness)['from'], '10f');
    });
  });

  group('the razor button', () {
    testWidgets('cuts the selected clip at the playhead', (tester) async {
      final harness = await _pump(tester);
      harness.container.read(timelineSelectionProvider.notifier).select({'el:el-clip'});
      // The clip runs 130..170 absolute; park the playhead inside it.
      harness.transport.seek(150);
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Razor at playhead'));
      await tester.pump();

      expect(_show(harness), {'from': '10f', 'to': '30f'});
      expect(harness.history.document.elementIdsInScene(1), hasLength(2));
    });

    testWidgets('is disabled, not hidden, when the playhead misses', (tester) async {
      // The verb stays where the hand learned to find it; hiding it would
      // make the timeline look like it had no razor at all.
      final harness = await _pump(tester);
      harness.transport.seek(10);
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Razor at playhead'));
      await tester.pump();

      expect(find.bySemanticsLabel('Razor at playhead'), findsOneWidget);
      expect(_show(harness), {'from': '10f', 'to': '50f'});
    });
  });
}
