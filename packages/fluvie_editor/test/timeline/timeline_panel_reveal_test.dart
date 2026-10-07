import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// A slide whose only element reveals through its intrinsic `reveal` prop —
/// so its one timeline bar carries no binding.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {'id': 'el-counter', 'type': 'Counter', 'to': 98, 'reveal': '2s'},
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.history);
  final ProviderContainer container;
  final DocumentHistory history;
  final List<int> scrubs = [];
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final harness = _Harness(container, DocumentHistory(EditorDocument.fromJson(_deck())));
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
                slide: 0,
                onCommand: harness.history.dispatch,
                onScrub: harness.scrubs.add,
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
/// and the ruler strip (24).
Offset _lanesOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 24);

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
  testWidgets('the reveal-only slide shows its timeline, not the empty state', (tester) async {
    await _pump(tester);
    expect(find.byType(TrackTimeline), findsOneWidget);
    expect(find.text('No animations on this slide yet.'), findsNothing);
  });

  testWidgets('tapping a binding-less reveal bar selects its element', (tester) async {
    final harness = await _pump(tester);
    // The reveal bar covers frames 0..60 → px 0..240; tap inside it.
    await tester.tapAt(_lanesOrigin(tester) + const Offset(60, 14));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-counter'});
  });

  testWidgets('dragging a binding-less reveal bar is a no-op', (tester) async {
    final harness = await _pump(tester);
    await _drag(tester, _lanesOrigin(tester) + const Offset(60, 14), const Offset(40, 0));
    // Nothing to retime: the document is untouched and nothing is undoable.
    expect(harness.history.canUndo, isFalse);
    expect(harness.history.document.elementJson('el-counter')!['reveal'], '2s');
    expect(harness.history.document.elementJson('el-counter')!.containsKey('animate'), isFalse);
  });

  testWidgets('resizing a binding-less reveal bar is a no-op', (tester) async {
    final harness = await _pump(tester);
    // Grab the left edge (px 1) — a resize gesture on a binding-less bar.
    await _drag(tester, _lanesOrigin(tester) + const Offset(1, 14), const Offset(32, 0));
    expect(harness.history.canUndo, isFalse);
    expect(harness.history.document.elementJson('el-counter')!['reveal'], '2s');
  });

  testWidgets('tapping the track past the reveal bar scrubs, not crashes', (tester) async {
    final harness = await _pump(tester);
    // Frame 80 (px 320) is empty lane space beyond the 60-frame reveal bar.
    await tester.tapAt(_lanesOrigin(tester) + const Offset(320, 14));
    await tester.pump();
    expect(harness.scrubs.single, 80);
  });
}
