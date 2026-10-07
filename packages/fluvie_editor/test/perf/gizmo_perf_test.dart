@Tags(['render'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show LivePlayer;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// The drag-responsiveness budget: streaming placement overrides through a
/// crowded slide must stay a relayout, not a re-derive. The structural
/// invariant (the derived subtree is never rebuilt) is pinned by the
/// interaction suite; this test pins the wall-clock cost.
Map<String, Object?> _crowdedDeck() => {
  'fluvieSpec': 1,
  'size': {'width': 640, 'height': 360},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#14141C'},
      'children': [
        for (var i = 0; i < 24; i++)
          {
            'id': 'el-$i',
            'type': 'Box',
            'color': '#6C5CE7',
            'transform': {
              'x': 0.1 + 0.8 * (i % 6) / 5,
              'y': 0.15 + 0.7 * (i ~/ 6) / 3,
              'w': 0.1,
              'h': 0.12,
            },
          },
      ],
    },
  ],
};

void main() {
  testWidgets('120 drag updates stay inside the frame budget', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final viewport = CanvasViewportController();
    final history = DocumentHistory(EditorDocument.fromJson(_crowdedDeck()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          title: 'perf',
          theme: OiThemeData.dark(),
          home: Center(
            child: SizedBox(
              width: 640,
              height: 360,
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
        ),
      ),
    );
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(EditorCanvas));
    // el-0 sits at canvas (64, 54); select it, then drag it around.
    final start = origin + viewport.toViewport(const Offset(64, 54));
    await tester.tapAt(start);
    await tester.pump();

    final player = tester.widget<LivePlayer>(find.byType(LivePlayer));
    final gesture = await tester.startGesture(start);
    await tester.pump();

    final stopwatch = Stopwatch()..start();
    for (var i = 1; i <= 120; i++) {
      await gesture.moveBy(const Offset(3, 1));
      await tester.pump();
    }
    stopwatch.stop();

    // The fast path never re-derived the slide mid-drag: the exact same
    // player subtree is still mounted after 120 updates.
    expect(identical(tester.widget<LivePlayer>(find.byType(LivePlayer)), player), isTrue);

    await gesture.up();
    await tester.pump();
    expect(history.canUndo, isTrue, reason: 'the release committed one step');

    final average = stopwatch.elapsedMilliseconds / 120;
    // Software rendering on CI: a re-derive-per-update regression costs an
    // order of magnitude more than this.
    expect(
      average,
      lessThan(8),
      reason:
          '120 drag updates took ${stopwatch.elapsedMilliseconds}ms '
          '(${average.toStringAsFixed(2)}ms per update)',
    );
  });
}
