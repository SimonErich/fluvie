// Which verb a bar drag turns out to be. Two pairs split by one modifier:
// on a body, Alt changes what plays and Shift changes when; on an edge, Alt
// lets the rest of the slide follow and Shift moves the cut.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// Two slides at 30 fps. The first is 200 frames and holds three clips laid
/// end to end (a 0..40, b 40..90, c 90..150); at the panel's 2 px/frame that
/// is lane pixels 0..80, 80..180 and 180..300 on rows 1, 2 and 3, with row 0
/// the scenes lane. The second slide gives the ruler a boundary hairline at
/// frame 200.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '200f',
      'children': [
        {
          'id': 'a',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/a.mp4'},
          'show': {'from': '0f', 'to': '40f'},
        },
        {
          'id': 'b',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/b.mp4'},
          'show': {'from': '40f', 'to': '90f'},
          'trim': {'from': '2.0s', 'to': '5.0s'},
        },
        {
          'id': 'c',
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'clips/c.mp4'},
          'show': {'from': '90f', 'to': '150f'},
        },
      ],
    },
    // A second slide, so the timeline draws a boundary hairline at frame 200.
    {
      'duration': '60f',
      'children': [
        {'id': 'd', 'type': 'Text', 'text': 'two'},
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.history);
  final DocumentHistory history;

  Map<String, Object?> show(String id) =>
      history.document.elementJson(id)!['show']! as Map<String, Object?>;

  Map<String, Object?>? trim(String id) =>
      history.document.elementJson(id)!['trim'] as Map<String, Object?>?;
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  final transport = SlideTransport(fps: 30, length: 260);
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
  return _Harness(history);
}

/// The lanes origin: the timeline's top-left plus the labels column (140)
/// and the ruler strip (24). Element lanes come after the scenes lane, in
/// document order, so a is row 1, b row 2 and c row 3.
Offset _row(WidgetTester tester, int row, double x) =>
    tester.getTopLeft(find.byType(TrackTimeline)) +
    const Offset(140, 24) +
    Offset(x, row * 28 + 14);

Future<void> _drag(WidgetTester tester, Offset from, double dx, {LogicalKeyboardKey? held}) async {
  if (held != null) await tester.sendKeyDownEvent(held);
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset(dx / 2, 0));
  await tester.pump();
  await gesture.moveBy(Offset(dx / 2, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();
  if (held != null) await tester.sendKeyUpEvent(held);
}

void main() {
  group('a body drag', () {
    testWidgets('plainly moves the clip', (tester) async {
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 2, 130), 20);

      expect(harness.show('b'), {'from': '50f', 'to': '100f'});
    });

    testWidgets('with Alt slips the source under a window that does not move', (tester) async {
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 2, 130), 20, held: LogicalKeyboardKey.altLeft);

      expect(harness.show('b'), {'from': '40f', 'to': '90f'}, reason: 'a slip holds the window');
      expect(harness.trim('b'), {'from': '2.3333333333333335s', 'to': '5.333333333333333s'});
    });

    testWidgets('with Shift slides it, and the neighbours absorb the move', (tester) async {
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 2, 130), 20, held: LogicalKeyboardKey.shiftLeft);

      expect(harness.show('a'), {'from': '0f', 'to': '50f'});
      expect(harness.show('b'), {'from': '50f', 'to': '100f'});
      expect(harness.show('c'), {'from': '100f', 'to': '150f'});
      expect(harness.trim('b'), {'from': '2.0s', 'to': '5.0s'}, reason: 'a slide holds content');
    });

    testWidgets('is one undo step whichever verb it turned out to be', (tester) async {
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 2, 130), 20, held: LogicalKeyboardKey.shiftLeft);
      harness.history.undo();

      expect(harness.show('a'), {'from': '0f', 'to': '40f'});
      expect(harness.show('b'), {'from': '40f', 'to': '90f'});
      expect(harness.history.canUndo, isFalse);
    });
  });

  group('an edge drag', () {
    testWidgets('plainly trims, leaving everything else alone', (tester) async {
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 2, 179), 20);

      expect(harness.show('b'), {'from': '40f', 'to': '100f'});
      expect(harness.show('c'), {'from': '90f', 'to': '150f'});
    });

    testWidgets('with Alt ripples, pushing what follows along', (tester) async {
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 2, 179), 20, held: LogicalKeyboardKey.altLeft);

      expect(harness.show('b'), {'from': '40f', 'to': '100f'});
      expect(harness.show('c'), {'from': '100f', 'to': '160f'});
    });

    testWidgets('with Shift rolls the cut, holding the pair outer edges', (tester) async {
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 2, 179), 20, held: LogicalKeyboardKey.shiftLeft);

      expect(harness.show('b'), {'from': '40f', 'to': '100f'});
      expect(harness.show('c'), {'from': '100f', 'to': '150f'});
      expect(harness.show('a'), {'from': '0f', 'to': '40f'});
    });

    testWidgets('rolls from the head too, against the clip before it', (tester) async {
      // The cut at a clip's head belongs to the clip before it, so naming it
      // from either side has to move the same one cut.
      final harness = await _pump(tester);

      await _drag(tester, _row(tester, 2, 81), 20, held: LogicalKeyboardKey.shiftLeft);

      expect(harness.show('a'), {'from': '0f', 'to': '50f'});
      expect(harness.show('b'), {'from': '50f', 'to': '90f'});
    });
  });

  group('a boundary hairline', () {
    testWidgets('retimes the slide before it when dragged', (tester) async {
      // The slide runs 0..200; dragging its boundary marker left to frame 150
      // shortens it to 150 and pulls the video in with it.
      final harness = await _pump(tester);
      final ruler = tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 12);

      // The boundary sits at frame 200, which is px 400 at 2 px/frame.
      await _drag(tester, ruler + const Offset(400, 0), -100);

      expect(harness.history.document.sceneJson(0)['duration'], '150f');
    });

    testWidgets('is one undo step for the whole drag', (tester) async {
      final harness = await _pump(tester);
      final ruler = tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 12);

      await _drag(tester, ruler + const Offset(400, 0), -100);
      harness.history.undo();

      expect(harness.history.document.sceneJson(0)['duration'], '200f');
      expect(harness.history.canUndo, isFalse);
    });
  });
}
