import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

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
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {
              'id': 'el-ga',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.25, 'y': 0.5, 'w': 0.5, 'h': 1.0},
            },
            {
              'id': 'el-gb',
              'type': 'Box',
              'color': '#2ECC8F',
              'transform': {'x': 0.75, 'y': 0.5, 'w': 0.5, 'h': 1.0},
            },
          ],
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.viewport, this.history);

  final ProviderContainer container;
  final CanvasViewportController viewport;
  final DocumentHistory history;

  EditorDocument get document => history.document;

  Set<String> get selection => container.read(selectionProvider);

  String? get entered => container.read(enteredGroupProvider);
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final viewport = CanvasViewportController();
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
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
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, viewport, history);
}

/// The viewport point over canvas pixel [point].
Offset _at(WidgetTester tester, _Harness harness, Offset point) =>
    tester.getTopLeft(find.byType(EditorCanvas)) + harness.viewport.toViewport(point);

Future<void> _doubleTapAt(WidgetTester tester, Offset where) async {
  await tester.tapAt(where);
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tapAt(where);
  await tester.pump();
}

Future<void> _enterGroup(WidgetTester tester, _Harness harness) async {
  await _doubleTapAt(tester, _at(tester, harness, const Offset(100, 90)));
}

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

void main() {
  group('EnteredGroupController', () {
    test('enters and exits', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(enteredGroupProvider), isNull);
      container.read(enteredGroupProvider.notifier).enter('el-g');
      expect(container.read(enteredGroupProvider), 'el-g');
      container.read(enteredGroupProvider.notifier).exit();
      expect(container.read(enteredGroupProvider), isNull);
    });
  });

  group('entering a group', () {
    testWidgets('a single click selects the group as one unit', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(100, 90)));
      await tester.pump();
      expect(harness.selection, {'el-g'});
      expect(harness.entered, isNull);
    });

    testWidgets('a double-click enters; clicks then select children', (tester) async {
      final harness = await _pump(tester);
      await _enterGroup(tester, harness);
      expect(harness.entered, 'el-g');
      await tester.tapAt(_at(tester, harness, const Offset(200, 90)));
      await tester.pump();
      expect(harness.selection, {'el-gb'});
    });

    testWidgets('a child drag writes the child transform, group untouched', (tester) async {
      final harness = await _pump(tester);
      await _enterGroup(tester, harness);
      final start = _at(tester, harness, const Offset(100, 90));
      final gesture = await tester.startGesture(start);
      await gesture.moveTo(_at(tester, harness, const Offset(140, 90)));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      final transform = harness.document.elementJson('el-ga')!['transform']! as Map;
      // +40 canvas px inside a 160 px wide group box: 0.25 + 0.25.
      expect((transform['x']! as num).toDouble(), closeTo(0.5, 1e-6));
      expect(
        harness.document.elementJson('el-g')?['transform'],
        {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
      );
      harness.history.undo();
      final restored = harness.document.elementJson('el-ga')!['transform']! as Map;
      expect((restored['x']! as num).toDouble(), closeTo(0.25, 1e-6));
    });

    testWidgets('Escape exits the group and selects it', (tester) async {
      final harness = await _pump(tester);
      await _enterGroup(tester, harness);
      await tester.tapAt(_at(tester, harness, const Offset(100, 90)));
      await tester.pump();
      expect(harness.selection, {'el-ga'});
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(harness.entered, isNull);
      expect(harness.selection, {'el-g'});
    });

    testWidgets('a click outside the group exits it', (tester) async {
      final harness = await _pump(tester);
      await _enterGroup(tester, harness);
      await tester.tapAt(_at(tester, harness, const Offset(288, 90)));
      await tester.pump();
      expect(harness.entered, isNull);
      expect(harness.selection, {'el-x'});
    });

    testWidgets('a hidden child stops hitting inside the group', (tester) async {
      final harness = await _pump(tester);
      harness.history.dispatch(
        const SetElementsVisibleCommand(ids: ['el-ga'], visible: false),
      );
      await tester.pump();
      await _enterGroup(tester, harness);
      await tester.tapAt(_at(tester, harness, const Offset(100, 90)));
      await tester.pump();
      expect(harness.selection, isEmpty);
    });
  });

  group('the arrange shortcuts', () {
    testWidgets('Ctrl+G groups the selection at its bounding box', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(_at(tester, harness, const Offset(288, 90)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(harness.selection, {'el-y', 'el-x'});
      await _chord(tester, LogicalKeyboardKey.keyG, control: true);
      expect(harness.document.elementIdsInScene(0), ['el-1', 'el-g']);
      expect(harness.document.childIdsOfGroup('el-1'), ['el-y', 'el-x']);
      expect(harness.document.elementJson('el-1')?['transform'], {
        'x': 0.5,
        'y': 0.5,
        'w': 0.9,
        'h': 0.2,
      });
      expect(harness.selection, {'el-1'});
      harness.history.undo();
      expect(harness.document.elementIdsInScene(0), ['el-y', 'el-x', 'el-g']);
    });

    testWidgets('Ctrl+Shift+G ungroups and selects the children', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(100, 90)));
      await tester.pump();
      await _chord(tester, LogicalKeyboardKey.keyG, control: true, shift: true);
      expect(
        harness.document.elementIdsInScene(0),
        ['el-y', 'el-x', 'el-ga', 'el-gb'],
      );
      expect(harness.selection, {'el-ga', 'el-gb'});
    });

    testWidgets('brackets step the z-order; Ctrl jumps to the end', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.pump();
      await _chord(tester, LogicalKeyboardKey.bracketRight);
      expect(harness.document.elementIdsInScene(0), ['el-x', 'el-y', 'el-g']);
      await _chord(tester, LogicalKeyboardKey.bracketRight, control: true);
      expect(harness.document.elementIdsInScene(0), ['el-x', 'el-g', 'el-y']);
      await _chord(tester, LogicalKeyboardKey.bracketLeft);
      expect(harness.document.elementIdsInScene(0), ['el-x', 'el-y', 'el-g']);
      await _chord(tester, LogicalKeyboardKey.bracketLeft, control: true);
      expect(harness.document.elementIdsInScene(0), ['el-y', 'el-x', 'el-g']);
    });

    testWidgets('inside an entered group the brackets reorder its children', (tester) async {
      final harness = await _pump(tester);
      await _enterGroup(tester, harness);
      await tester.tapAt(_at(tester, harness, const Offset(100, 90)));
      await tester.pump();
      expect(harness.selection, {'el-ga'});
      await _chord(tester, LogicalKeyboardKey.bracketRight);
      expect(harness.document.childIdsOfGroup('el-g'), ['el-gb', 'el-ga']);
      expect(harness.document.elementIdsInScene(0), ['el-y', 'el-x', 'el-g']);
    });

    testWidgets('grouping needs two elements; a lone selection is a no-op', (tester) async {
      final harness = await _pump(tester);
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.pump();
      await _chord(tester, LogicalKeyboardKey.keyG, control: true);
      expect(harness.document.elementIdsInScene(0), ['el-y', 'el-x', 'el-g']);
      expect(harness.history.canUndo, isFalse);
    });

    testWidgets('the no-op chords never dirty the history', (tester) async {
      final harness = await _pump(tester);
      // Brackets without a selection.
      await _chord(tester, LogicalKeyboardKey.bracketRight);
      // Ungroup over a non-group selection.
      await tester.tapAt(_at(tester, harness, const Offset(32, 90)));
      await tester.pump();
      await _chord(tester, LogicalKeyboardKey.keyG, control: true, shift: true);
      // Group while inside an entered group.
      await _enterGroup(tester, harness);
      await _chord(tester, LogicalKeyboardKey.keyG, control: true);
      expect(harness.history.canUndo, isFalse);
    });
  });
}
