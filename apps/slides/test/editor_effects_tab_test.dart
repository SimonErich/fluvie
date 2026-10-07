// The Effects tab in the real editor shell: select an element, open the
// tab, add an effect from the browser, and keyframe its parameter with the
// diamond — the whole journey against a known deck.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Box;
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas, EditorDocument;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;
import 'package:slides/editor/editor_screen.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

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
          'id': 'el-left',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.25, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
      ],
    },
  ],
};

Future<void> _pump(WidgetTester tester) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorScreen(
        document: EditorDocument.fromJson(_deck()),
        title: 'mine.fluvie',
        onClose: () {},
        autosave: MemoryAutosaveStore(),
      ),
    ),
  );
  await tester.pump();
}

/// The screen point over canvas-pixel [point], replicating the canvas's
/// initial fit (`CanvasViewportController.fit`, margin 48).
Offset _at(WidgetTester tester, Offset point) {
  final canvas = tester.getRect(find.byType(EditorCanvas));
  const size = Size(320, 180);
  const margin = 48.0;
  final scale = math.min(
    (canvas.width - 2 * margin) / size.width,
    (canvas.height - 2 * margin) / size.height,
  );
  final origin = canvas.center - Offset(size.width / 2 * scale, size.height / 2 * scale);
  return origin + point * scale;
}

Map<String, Object?> _element(WidgetTester tester) =>
    tester.widget<EditorCanvas>(find.byType(EditorCanvas).first).document.elementJson('el-left')!;

void main() {
  testWidgets('video mode mounts the Effects tab beside the timeline', (tester) async {
    await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Video mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Effects'));
    await tester.pump();
    expect(find.text('Select an element to stack effects on it.'), findsOneWidget);

    // Select the box where it actually paints on the whole-video canvas.
    final painted = find.descendant(of: find.byType(EditorCanvas), matching: find.byType(Box));
    await tester.tapAt(tester.getCenter(painted.first));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('effect-chip-grain')));
    await tester.tap(find.byKey(const ValueKey('effect-chip-grain')));
    await tester.pump();

    expect((_element(tester)['effects']! as List).single, {'kind': 'grain'});

    // Keyframe it, then collapse it at the whole-video playhead: the flat
    // ramp reads its own value everywhere, so the literal comes back.
    await tester.ensureVisible(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.tap(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.pump();

    expect(((_element(tester)['effects']! as List).single! as Map)['amount'], 0.2);
  });

  testWidgets('the Effects tab adds and keyframes an effect on the selection', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Effects'));
    await tester.pump();
    expect(find.text('Select an element to stack effects on it.'), findsOneWidget);

    // Select the box, then stack a vignette on it from the browser.
    await tester.tapAt(_at(tester, const Offset(80, 90)));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('effect-chip-vignette')));
    await tester.tap(find.byKey(const ValueKey('effect-chip-vignette')));
    await tester.pump();

    expect((_element(tester)['effects']! as List).single, {'kind': 'vignette'});

    // The diamond keyframes the amount into a flat ramp over the slide.
    await tester.ensureVisible(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.tap(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.pump();

    final effects = _element(tester)['effects']! as List;
    final amount = ((effects.single! as Map)['amount']! as Map).cast<String, Object?>();
    expect(amount['values'], [0.4, 0.4]);
    expect(amount['positions'], ['0f', '60f']);

    // Collapse at the playhead: the flat ramp reads 0.4 everywhere, so the
    // literal comes back through the slides playhead closure.
    await tester.tap(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.pump();

    expect(((_element(tester)['effects']! as List).single! as Map)['amount'], 0.4);
  });
}
