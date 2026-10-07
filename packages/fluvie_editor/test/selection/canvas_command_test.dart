import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiCommandBar, OiThemeData;

import '../commands/fake_system_clipboard.dart';

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
          'id': 'el-y',
          'type': 'Box',
          'color': '#E17055',
          'transform': {'x': 0.1, 'y': 0.5, 'w': 0.1, 'h': 0.2},
        },
        {
          'id': 'el-x',
          'type': 'Box',
          'color': '#0984E3',
          'transform': {'x': 0.9, 'y': 0.5, 'w': 0.1, 'h': 0.2},
        },
      ],
    },
    {'duration': '60f', 'children': <Object?>[]},
  ],
};

final class _Harness {
  _Harness(this.container, this.viewport, this.history);

  final ProviderContainer container;
  final CanvasViewportController viewport;
  final DocumentHistory history;
  int shownSlide = -1;

  EditorDocument get document => history.document;

  Set<String> get selection => container.read(selectionProvider);
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final viewport = CanvasViewportController();
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  final harness = _Harness(container, viewport, history);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 320,
            height: 180,
            child: ListenableBuilder(
              listenable: history,
              builder: (context, _) => EditorCanvas(
                document: history.document,
                slide: 0,
                viewportController: viewport,
                fitMargin: 0,
                interactive: true,
                onCommand: history.dispatch,
                onShowSlide: (slide) => harness.shownSlide = slide,
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

Offset _at(WidgetTester tester, _Harness harness, Offset point) =>
    tester.getTopLeft(find.byType(EditorCanvas)) + harness.viewport.toViewport(point);

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool shift = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// Right-clicks at [where] with a mouse. No hover needed: the menu host
/// hit-tests the press position itself.
Future<void> _rightClickAt(WidgetTester tester, Offset where) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.addPointer(location: where);
  addTearDown(gesture.removePointer);
  await gesture.down(where);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  final fake = FakeSystemClipboard();
  setUp(fake.install);
  tearDown(() {
    fake
      ..text = null
      ..uninstall();
  });

  group('registry shortcuts on the canvas', () {
    testWidgets('Ctrl+C then Ctrl+V pastes a nudged copy with a fresh id', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.pump();
      expect(harness.selection, {'el-y'});
      await _chord(tester, LogicalKeyboardKey.keyC, control: true);
      await _chord(tester, LogicalKeyboardKey.keyV, control: true);
      await tester.pump();
      final ids = harness.document.elementIdsInScene(0);
      expect(ids, hasLength(3));
      expect(ids.last, isNot('el-y'));
      expect(harness.selection, {ids.last});
    });

    testWidgets('Delete removes a multi-selection in one undo step', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(_at(tester, harness, const Offset(288, 90)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(harness.selection, {'el-y', 'el-x'});
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(harness.document.elementIdsInScene(0), isEmpty);
      expect(harness.selection, isEmpty);
      harness.history.undo();
      expect(harness.document.elementIdsInScene(0), ['el-y', 'el-x']);
    });

    testWidgets('Ctrl+D duplicates the selection', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.pump();
      await _chord(tester, LogicalKeyboardKey.keyD, control: true);
      expect(harness.document.elementIdsInScene(0), hasLength(3));
    });

    testWidgets('Ctrl+A selects everything selectable', (tester) async {
      final harness = await _pump(tester);
      await _chord(tester, LogicalKeyboardKey.keyA, control: true);
      expect(harness.selection, {'el-y', 'el-x'});
    });

    testWidgets('Ctrl+Shift+H hides the selection through the registry', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.pump();
      await _chord(tester, LogicalKeyboardKey.keyH, control: true, shift: true);
      expect(harness.document.elementJson('el-y')!['visible'], isFalse);
    });

    testWidgets('bare letters still switch tools, not commands', (tester) async {
      final harness = await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pump();
      expect(harness.container.read(toolProvider).tool, EditorTool.hand);
    });
  });

  group('the canvas context menus', () {
    testWidgets('right-click over an element opens the element menu and selects it', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _rightClickAt(tester, _at(tester, harness, const Offset(32, 90)));
      expect(harness.selection, {'el-y'});
      expect(find.text('Cut'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Select all'), findsNothing);
    });

    testWidgets('right-click over empty canvas opens the canvas menu', (tester) async {
      final harness = await _pump(tester);
      await _rightClickAt(tester, _at(tester, harness, const Offset(160, 20)));
      expect(harness.selection, isEmpty);
      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('Cut'), findsNothing);
    });

    testWidgets('a menu tap fires the command', (tester) async {
      final harness = await _pump(tester);
      await _rightClickAt(tester, _at(tester, harness, const Offset(32, 90)));
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(harness.document.elementIdsInScene(0), hasLength(3));
    });

    testWidgets('items disabled by context ignore taps', (tester) async {
      final harness = await _pump(tester);
      await _rightClickAt(tester, _at(tester, harness, const Offset(32, 90)));
      // A single non-group selection cannot ungroup.
      await tester.tap(find.text('Ungroup'));
      await tester.pumpAndSettle();
      expect(harness.history.canUndo, isFalse);
      expect(harness.document.elementIdsInScene(0), ['el-y', 'el-x']);
    });

    testWidgets('the align submenu drills down and fires', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(_at(tester, harness, const Offset(288, 90)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await _rightClickAt(tester, _at(tester, harness, const Offset(32, 90)));
      await tester.tap(find.text('Align'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Align top'));
      await tester.pumpAndSettle();
      final geometry = SceneGeometry.of(harness.document, 0);
      expect(geometry.rectOf('el-y')!.top, closeTo(geometry.rectOf('el-x')!.top, 1e-6));
      expect(harness.history.undoLabel, 'Align top');
    });

    testWidgets('the canvas menu duplicates the slide and follows it', (tester) async {
      final harness = await _pump(tester);
      await _rightClickAt(tester, _at(tester, harness, const Offset(160, 20)));
      await tester.tap(find.text('Duplicate slide'));
      await tester.pumpAndSettle();
      expect(harness.document.sceneCount, 3);
      expect(harness.shownSlide, 1);
    });
  });

  group('the palette over the canvas', () {
    testWidgets('Ctrl+K opens it; a command executes against the selection', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.pump();
      await _chord(tester, LogicalKeyboardKey.keyK, control: true);
      expect(find.byType(OiCommandBar), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'duplicate');
      await tester.pump();
      await tester.tap(find.text('Duplicate').first);
      await tester.pumpAndSettle();
      expect(harness.document.elementIdsInScene(0), hasLength(3));
      expect(find.byType(OiCommandBar), findsNothing);
    });

    testWidgets('the canvas keeps its keys after the palette closes', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.pump();
      await _chord(tester, LogicalKeyboardKey.keyK, control: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(OiCommandBar), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(harness.document.elementIdsInScene(0), ['el-x']);
    });
  });
}
