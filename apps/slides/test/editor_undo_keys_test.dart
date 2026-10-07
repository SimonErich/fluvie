import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart'
    show EditorCanvas, EditorDocument, EditorTip, LayersPanel;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiIconButton, OiThemeData;
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
        {
          'id': 'el-right',
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.75, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
      ],
    },
  ],
};

final class _Harness {
  final List<EditorDocument> documents = [];
}

Future<_Harness> _pump(WidgetTester tester) async {
  useDesktopSurface(tester);
  final harness = _Harness();
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
  return harness;
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

double _leftX(WidgetTester tester) {
  final canvas = tester
      .widget<EditorCanvas>(find.byType(EditorCanvas).first)
      .document
      .elementJson('el-left')!;
  return ((canvas['transform']! as Map)['x']! as num).toDouble();
}

Future<void> _nudgeLeftBox(WidgetTester tester) async {
  await tester.tapAt(_at(tester, const Offset(80, 90)));
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pump();
  expect(_leftX(tester), closeTo(0.25 + 1 / 320, 1e-9));
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets('Ctrl+Z undoes with canvas focus, Ctrl+Shift+Z and Ctrl+Y redo', (tester) async {
    await _pump(tester);
    await _nudgeLeftBox(tester);

    await _chord(tester, LogicalKeyboardKey.keyZ);
    expect(_leftX(tester), 0.25);

    await _chord(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(_leftX(tester), closeTo(0.25 + 1 / 320, 1e-9));

    await _chord(tester, LogicalKeyboardKey.keyZ);
    expect(_leftX(tester), 0.25);

    await _chord(tester, LogicalKeyboardKey.keyY);
    expect(_leftX(tester), closeTo(0.25 + 1 / 320, 1e-9));
  });

  testWidgets('the chord reaches the history from a panel focus too', (tester) async {
    await _pump(tester);
    await _nudgeLeftBox(tester);

    // Move focus off the canvas and onto a Layers-panel row button: its
    // tappable's focus node wraps the inner GestureDetector.
    await tester.tap(find.text('Layers'));
    await tester.pump();
    final button = find
        .descendant(of: find.byType(LayersPanel), matching: find.byType(OiIconButton))
        .evaluate()
        .firstWhere((element) => (element.widget as OiIconButton).semanticLabel == 'Lock Box');
    final inner = find
        .descendant(of: find.byWidget(button.widget), matching: find.byType(GestureDetector))
        .first;
    Focus.of(tester.element(inner)).requestFocus();
    await tester.pump();
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      isNot('canvas'),
      reason: 'the panel, not the canvas, must hold focus for this probe',
    );

    await _chord(tester, LogicalKeyboardKey.keyZ);
    expect(_leftX(tester), 0.25);

    await _chord(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(_leftX(tester), closeTo(0.25 + 1 / 320, 1e-9));
  });

  testWidgets('an idle Ctrl+Z keeps the selection', (tester) async {
    await _pump(tester);
    await tester.tapAt(_at(tester, const Offset(80, 90)));
    await tester.pump();
    // Nothing to undo: the chord must not clear the selection by
    // re-selecting an empty affected set.
    await _chord(tester, LogicalKeyboardKey.keyZ);
    final tips = tester.widgetList<EditorTip>(find.byType(EditorTip));
    expect(tips.any((tip) => tip.message.startsWith('Undo the last step')), isTrue);
    expect(_leftX(tester), 0.25);
  });

  testWidgets('the top bar tooltips carry the registry chords', (tester) async {
    await _pump(tester);
    final messages = [
      for (final tip in tester.widgetList<EditorTip>(find.byType(EditorTip))) tip.message,
    ];
    expect(messages, contains('Undo the last step (Ctrl+Z)'));
    expect(messages, contains('Redo the undone step (Ctrl+Shift+Z)'));
  });
}
