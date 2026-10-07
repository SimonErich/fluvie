import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck({bool animated = true}) => {
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
          if (animated)
            'animate': [
              {'preset': 'fadeIn', 'duration': '30f'},
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
  final List<int> scrubs = [];
}

Future<_Harness> _pump(WidgetTester tester, {bool animated = true}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final harness = _Harness(
    container,
    DocumentHistory(EditorDocument.fromJson(_deck(animated: animated))),
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

List<Map<String, Object?>> _animate(EditorDocument document) =>
    (document.elementJson('el-a')!['animate']! as List).cast<Map<String, Object?>>();

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
  testWidgets('the panel shows the timeline under a header with the track', (tester) async {
    await _pump(tester);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.byType(TrackTimeline), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
  });

  testWidgets('dragging a bar retimes through one merged undo step', (tester) async {
    final harness = await _pump(tester);
    // The fadeIn bar covers frames 0..30 → px 0..120 at the default zoom.
    await _drag(tester, _lanesOrigin(tester) + const Offset(60, 14), const Offset(40, 0));
    final animate = _animate(harness.history.document);
    expect(animate.first['delay'], '10f');
    harness.history.undo();
    expect(_animate(harness.history.document).first.containsKey('delay'), isFalse);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('dragging the right edge trims the duration', (tester) async {
    final harness = await _pump(tester);
    await _drag(tester, _lanesOrigin(tester) + const Offset(119, 14), const Offset(-20, 0));
    final animate = _animate(harness.history.document);
    expect(animate.first['duration'], '25f');
    expect(animate.first.containsKey('delay'), isFalse);
    harness.history.undo();
    expect(_animate(harness.history.document).first['duration'], '30f');
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('dragging the left edge writes delay and duration together', (tester) async {
    final harness = await _pump(tester);
    await _drag(tester, _lanesOrigin(tester) + const Offset(1, 14), const Offset(32, 0));
    final animate = _animate(harness.history.document);
    expect(animate.first['delay'], '8f');
    expect(animate.first['duration'], '22f');
  });

  testWidgets('tapping empty lane space moves the playhead there', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_lanesOrigin(tester) + const Offset(200, 14));
    await tester.pump();
    expect(harness.scrubs.single, 50);
  });

  testWidgets('scrubbing the ruler reports whole frames', (tester) async {
    final harness = await _pump(tester);
    final ruler = tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 12);
    await _drag(tester, ruler + const Offset(80, 0), const Offset(40, 0));
    expect(harness.scrubs.first, 20);
    expect(harness.scrubs.last, 30);
  });

  testWidgets('tapping a bar selects its element', (tester) async {
    final harness = await _pump(tester);
    await tester.tapAt(_lanesOrigin(tester) + const Offset(60, 14));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-a'});
  });

  testWidgets('the header collapse control folds the panel away', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Collapse the timeline'));
    await tester.pump();
    expect(find.byType(TrackTimeline), findsNothing);
    expect(find.text('Timeline'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Show the timeline'));
    await tester.pump();
    expect(find.byType(TrackTimeline), findsOneWidget);
  });

  testWidgets('an animation-less slide offers to add one', (tester) async {
    final harness = await _pump(tester, animated: false);
    expect(find.text('No animations on this slide yet.'), findsOneWidget);
    await tester.tap(find.text('Add an animation'));
    await tester.pump();
    expect(_animate(harness.history.document).single['preset'], 'fadeIn');
    expect(find.byType(TrackTimeline), findsOneWidget);
    expect(find.text('No animations on this slide yet.'), findsNothing);
  });
}
