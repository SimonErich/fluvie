import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// Two elements on a 120-frame slide at the default zoom (4 px/frame):
/// el-a fades in over frames 0..30 (row 1, px 0..120) and el-b over frames
/// 60..90 (row 0, px 240..360, handle at px 300).
Map<String, Object?> _deck({
  Map<String, Object?>? bAt,
  String? aAnchor,
  Map<String, Object?>? aAt,
  String? bAnchor,
  bool twoOnA = false,
}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'anchor': ?aAnchor,
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f', 'at': ?aAt},
            if (twoOnA) {'preset': 'fadeOut', 'duration': '30f'},
          ],
        },
        {
          'id': 'el-b',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'anchor': ?bAnchor,
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f', 'delay': '60f', 'at': ?bAt},
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

Future<_Harness> _pump(WidgetTester tester, Map<String, Object?> deck) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final harness = _Harness(container, DocumentHistory(EditorDocument.fromJson(deck)));
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

Map<String, Object?> _animation(EditorDocument document, String id, [int index = 0]) =>
    ((document.elementJson(id)!['animate']! as List)[index]! as Map).cast<String, Object?>();

Offset _lanesOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 24);

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  final by = to - from;
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('dropping a link mints the anchor and writes whenEnds', (tester) async {
    final harness = await _pump(tester, _deck());
    final origin = _lanesOrigin(tester);
    // el-b rides row 0 (topmost); its handle sits at px 300, bar top + 4.
    await _drag(tester, origin + const Offset(300, 4), origin + const Offset(60, 42));
    final animation = _animation(harness.history.document, 'el-b');
    expect(animation['at'], {'kind': 'whenEnds', 'anchor': 'el-a'});
    expect(harness.history.document.elementJson('el-a')!['anchor'], 'el-a');
    // One undo reverts the trigger and the minted anchor together.
    harness.history.undo();
    expect(_animation(harness.history.document, 'el-b').containsKey('at'), isFalse);
    expect(harness.history.document.elementJson('el-a')!.containsKey('anchor'), isFalse);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('a drop reuses the target existing anchor id', (tester) async {
    final harness = await _pump(tester, _deck(aAnchor: 'hero'));
    final origin = _lanesOrigin(tester);
    await _drag(tester, origin + const Offset(300, 4), origin + const Offset(60, 42));
    expect(_animation(harness.history.document, 'el-b')['at'], {
      'kind': 'whenEnds',
      'anchor': 'hero',
    });
    expect(harness.history.document.elementJson('el-a')!['anchor'], 'hero');
  });

  testWidgets('the created link round-trips through save and reload', (tester) async {
    final harness = await _pump(tester, _deck());
    final origin = _lanesOrigin(tester);
    await _drag(tester, origin + const Offset(300, 4), origin + const Offset(60, 42));
    final reloaded = EditorDocument.fromJson(harness.history.document.toJson());
    const palette = TimelinePhasePalette(
      enter: Color(0xFF00FF00),
      during: Color(0xFFFFFF00),
      exit: Color(0xFFFF0000),
    );
    const links = TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF));
    SlideTimelineModel model(EditorDocument document) => SlideTimelineModel.build(
      document: document,
      slide: 0,
      palette: palette,
      linkPalette: links,
    );
    expect(model(reloaded).links, model(harness.history.document).links);
    expect(model(reloaded).links.single.toBarId, 'el-a:0');
  });

  testWidgets('dropping on the same element previous bar writes previous', (tester) async {
    final harness = await _pump(tester, _deck(twoOnA: true));
    final origin = _lanesOrigin(tester);
    // el-a rides row 1: fadeIn px 0..120, fadeOut end-anchored px 360..480
    // (handle at px 420). Drop the fadeOut onto the fadeIn.
    await _drag(tester, origin + const Offset(420, 32), origin + const Offset(60, 42));
    expect(_animation(harness.history.document, 'el-a', 1)['at'], 'previous');
  });

  testWidgets('a drop that would cycle the graph is refused', (tester) async {
    // el-a already chains off el-b (whenEnds b), pushing its bar to frames
    // 90..120 (px 360..480 on row 1); dropping el-b's trigger onto it would
    // close the cycle a -> b -> a.
    final harness = await _pump(
      tester,
      _deck(
        aAnchor: 'a',
        bAnchor: 'b',
        aAt: {'kind': 'whenEnds', 'anchor': 'b'},
      ),
    );
    final before = harness.history.document.toJson();
    final origin = _lanesOrigin(tester);
    await _drag(tester, origin + const Offset(300, 4), origin + const Offset(420, 42));
    expect(harness.history.document.toJson(), before);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('tapping the connector then Delete reverts the trigger to auto', (tester) async {
    final harness = await _pump(
      tester,
      _deck(aAnchor: 'hero', bAt: {'kind': 'whenEnds', 'anchor': 'hero'}),
    );
    final origin = _lanesOrigin(tester);
    // el-b now starts 60f after el-a ends (frames 90..120, px 360..480 on
    // row 0); the connector rises from el-a's end (px 120, row 1) to row 0
    // and runs horizontally into el-b's start — tappable clear of any bar.
    await tester.tapAt(origin + const Offset(200, 14));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(_animation(harness.history.document, 'el-b').containsKey('at'), isFalse);
  });
}
