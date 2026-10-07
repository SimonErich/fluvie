import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'a',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
    {
      'duration': '90f',
      'children': [
        {
          'id': 'el-b',
          'type': 'Text',
          'text': 'b',
          'animate': [
            {'preset': 'fadeIn', 'duration': '15f'},
          ],
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.history);
  final DocumentHistory history;
  final List<int> scrubs = [];
  final List<bool> opens = [];
}

Future<_Harness> _pump(
  WidgetTester tester,
  SlideTransport transport, {
  int slide = 0,
  _Harness? harness,
}) async {
  final built = harness ?? _Harness(DocumentHistory(EditorDocument.fromJson(_deck())));
  await tester.pumpWidget(
    ProviderScope(
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 640,
            child: TimelinePanel(
              document: built.history.document,
              slide: slide,
              transport: transport,
              onCommand: built.history.dispatch,
              onScrub: built.scrubs.add,
              onOpenChanged: built.opens.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return built;
}

SlideTransport _transport({int length = 120, int frame = 0}) => SlideTransport(
  fps: 30,
  length: length,
  initialFrame: frame,
);

TrackTimeline _timeline(WidgetTester tester) =>
    tester.widget<TrackTimeline>(find.byType(TrackTimeline));

Offset _ruler(WidgetTester tester) =>
    tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 12);

Future<void> _drag(WidgetTester tester, Offset from, Offset by, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset(by.dx / 2, 0));
  await tester.pump();
  await gesture.moveBy(Offset(by.dx / 2, 0));
  await tester.pump();
  await gesture.up();
  await tester.pump();
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

void main() {
  testWidgets('the transport frame is the ruler playhead', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    await _pump(tester, transport);
    expect(_timeline(tester).playhead, 0);
    transport.seek(40);
    await tester.pump();
    expect(_timeline(tester).playhead, 40);
  });

  testWidgets('scrubbing seeks the transport frame-exactly', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    final harness = await _pump(tester, transport);
    await _drag(tester, _ruler(tester) + const Offset(80, 0), const Offset(40, 0));
    expect(transport.frame, 30);
    expect(transport.isPlaying, isFalse);
    expect(_timeline(tester).playhead, 30);
    expect(harness.scrubs.last, 30);
  });

  testWidgets('the header play control toggles playback', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    await _pump(tester, transport);
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();
    expect(transport.isPlaying, isTrue);
    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    expect(transport.isPlaying, isFalse);
  });

  testWidgets('the readout shows the exact frame over seconds', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    await _pump(tester, transport);
    expect(find.text('f0 · 0.0s / 4.0s'), findsOneWidget);
    transport.seek(30);
    await tester.pump();
    expect(find.text('f30 · 1.0s / 4.0s'), findsOneWidget);
  });

  testWidgets('a shift-drag selects a range and the loop toggle arms it', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    await _pump(tester, transport);
    expect(find.bySemanticsLabel('Loop the selected range'), findsNothing);
    await _drag(tester, _ruler(tester) + const Offset(80, 0), const Offset(80, 0), shift: true);
    expect(transport.loop, isNull);
    await tester.tap(find.bySemanticsLabel('Loop the selected range'));
    await tester.pump();
    expect(transport.loop, const FrameRange(20, 40));
    await tester.tap(find.bySemanticsLabel('Stop looping'));
    await tester.pump();
    expect(transport.loop, isNull);
  });

  testWidgets('a new range retargets an armed loop', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    await _pump(tester, transport);
    await _drag(tester, _ruler(tester) + const Offset(80, 0), const Offset(80, 0), shift: true);
    await tester.tap(find.bySemanticsLabel('Loop the selected range'));
    await tester.pump();
    expect(transport.loop, const FrameRange(20, 40));
    await _drag(tester, _ruler(tester) + const Offset(200, 0), const Offset(40, 0), shift: true);
    expect(transport.loop, const FrameRange(50, 60));
  });

  testWidgets('Escape clears the range and disarms the loop', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    await _pump(tester, transport);
    await _drag(tester, _ruler(tester) + const Offset(80, 0), const Offset(80, 0), shift: true);
    await tester.tap(find.bySemanticsLabel('Loop the selected range'));
    await tester.pump();
    expect(transport.loop, const FrameRange(20, 40));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(transport.loop, isNull);
    expect(find.bySemanticsLabel('Loop the selected range'), findsNothing);
  });

  testWidgets('a zero-width shift-press never selects', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    await _pump(tester, transport);
    await _drag(tester, _ruler(tester) + const Offset(80, 0), Offset.zero, shift: true);
    expect(find.bySemanticsLabel('Loop the selected range'), findsNothing);
  });

  testWidgets('switching slides drops the range selection', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    final harness = await _pump(tester, transport);
    await _drag(tester, _ruler(tester) + const Offset(80, 0), const Offset(80, 0), shift: true);
    expect(find.bySemanticsLabel('Loop the selected range'), findsOneWidget);
    final next = _transport(length: 90);
    addTearDown(next.dispose);
    await _pump(tester, next, slide: 1, harness: harness);
    expect(find.bySemanticsLabel('Loop the selected range'), findsNothing);
  });

  testWidgets('the collapse control reports the open state', (tester) async {
    final transport = _transport();
    addTearDown(transport.dispose);
    final harness = await _pump(tester, transport);
    await tester.tap(find.bySemanticsLabel('Collapse the timeline'));
    await tester.pump();
    expect(harness.opens, [false]);
    await tester.tap(find.bySemanticsLabel('Show the timeline'));
    await tester.pump();
    expect(harness.opens, [false, true]);
  });
}
