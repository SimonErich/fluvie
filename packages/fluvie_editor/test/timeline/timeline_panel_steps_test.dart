import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// Three chained entrances on a 120-frame slide at the default zoom
/// (4 px/frame): el-1 settles at frame 20 (px 80), el-2 at 50 (px 200),
/// el-3 at 80 (px 320).
Map<String, Object?> _deck({List<Object?>? steps, Map<String, Object?>? el2At}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-1',
          'type': 'Box',
          'width': 40,
          'height': 20,
          'anchor': 'first',
          'animate': [
            {'preset': 'fadeIn', 'duration': '20f'},
          ],
        },
        {
          'id': 'el-2',
          'type': 'Box',
          'width': 40,
          'height': 20,
          'animate': [
            {'preset': 'fadeIn', 'duration': '20f', 'delay': '30f', 'at': ?el2At},
          ],
        },
        {
          'id': 'el-3',
          'type': 'Box',
          'width': 40,
          'height': 20,
          'animate': [
            {'preset': 'fadeIn', 'duration': '20f', 'delay': '60f'},
          ],
        },
      ],
      'steps': ?steps,
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

List<Object?>? _steps(EditorDocument document) => document.sceneJson(0)['steps'] as List<Object?>?;

Offset _rulerAt(WidgetTester tester, double dx) =>
    tester.getTopLeft(find.byType(TrackTimeline)) + Offset(140 + dx, 12);

Future<void> _drag(WidgetTester tester, Offset from, Offset by) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('a ruler double tap splits the step under it', (tester) async {
    final harness = await _pump(
      tester,
      _deck(
        steps: [
          {
            'elements': ['el-2', 'el-3'],
          },
        ],
      ),
    );
    // Frame 55 falls past the base marker (20): el-2 (settled at 50) stays,
    // el-3 (80) moves into a new click step.
    await tester.tapAt(_rulerAt(tester, 220));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(_rulerAt(tester, 220));
    await tester.pump();
    expect(_steps(harness.history.document), [
      {
        'elements': ['el-2'],
      },
      {
        'elements': ['el-3'],
      },
    ]);
    harness.history.undo();
    expect(_steps(harness.history.document), [
      {
        'elements': ['el-2', 'el-3'],
      },
    ]);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('a split separating nothing changes nothing', (tester) async {
    final harness = await _pump(
      tester,
      _deck(
        steps: [
          {
            'elements': ['el-2', 'el-3'],
          },
        ],
      ),
    );
    // Frame 10 sits in the base region and cannot split its only element.
    await tester.tapAt(_rulerAt(tester, 40));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(_rulerAt(tester, 40));
    await tester.pump();
    expect(_steps(harness.history.document), [
      {
        'elements': ['el-2', 'el-3'],
      },
    ]);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('dragging the base marker across a bar moves the element in', (tester) async {
    final harness = await _pump(
      tester,
      _deck(
        steps: [
          {
            'elements': ['el-2'],
          },
          {
            'elements': ['el-3'],
          },
        ],
      ),
    );
    // The base marker sits at frame 20 (px 80); dragging left of el-1's
    // settle pulls el-1 out of the base step and into the first click.
    await _drag(tester, _rulerAt(tester, 80), const Offset(-40, 0));
    expect(_steps(harness.history.document), [
      {
        'elements': ['el-1', 'el-2'],
      },
      {
        'elements': ['el-3'],
      },
    ]);
    // One drag, one undo step.
    harness.history.undo();
    expect(_steps(harness.history.document), [
      {
        'elements': ['el-2'],
      },
      {
        'elements': ['el-3'],
      },
    ]);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('a marker drag that would empty a click step is refused', (tester) async {
    final harness = await _pump(
      tester,
      _deck(
        steps: [
          {
            'elements': ['el-2'],
          },
          {
            'elements': ['el-3'],
          },
        ],
      ),
    );
    // Marker 1 sits at frame 50 (px 200); dragging past el-3's settle would
    // empty the last step.
    await _drag(tester, _rulerAt(tester, 200), const Offset(140, 0));
    expect(_steps(harness.history.document), [
      {
        'elements': ['el-2'],
      },
      {
        'elements': ['el-3'],
      },
    ]);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('selecting a marker and pressing Delete merges its steps', (tester) async {
    final harness = await _pump(
      tester,
      _deck(
        steps: [
          {
            'elements': ['el-2'],
          },
          {
            'elements': ['el-3'],
          },
        ],
      ),
    );
    // The base marker (frame 20, px 80): removing it folds step 1 back
    // into the base.
    await tester.tapAt(_rulerAt(tester, 80));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(_steps(harness.history.document), [
      {
        'elements': ['el-3'],
      },
    ]);
    harness.history.undo();
    expect(_steps(harness.history.document), hasLength(2));
  });

  testWidgets('dragging a marker off the ruler merges its steps too', (tester) async {
    final harness = await _pump(
      tester,
      _deck(
        steps: [
          {
            'elements': ['el-2'],
          },
          {
            'elements': ['el-3'],
          },
        ],
      ),
    );
    // Marker 1 (frame 50, px 200) dragged down into the lanes: step 2
    // merges into step 1, earlier notes winning.
    await _drag(tester, _rulerAt(tester, 200), const Offset(0, 80));
    expect(_steps(harness.history.document), [
      {
        'elements': ['el-2', 'el-3'],
      },
    ]);
  });

  testWidgets('removing the only marker drops the steps key entirely', (tester) async {
    final harness = await _pump(
      tester,
      _deck(
        steps: [
          {
            'elements': ['el-2', 'el-3'],
          },
        ],
      ),
    );
    await _drag(tester, _rulerAt(tester, 80), const Offset(0, 80));
    expect(harness.history.document.sceneJson(0).containsKey('steps'), isFalse);
  });

  testWidgets('a violation shows its message in the panel header', (tester) async {
    await _pump(
      tester,
      _deck(
        steps: [
          {
            'elements': ['el-2'],
          },
        ],
        el2At: {'kind': 'whenEnds', 'anchor': 'first'},
      ),
    );
    expect(find.textContaining('inside a Stop'), findsOneWidget);
  });

  testWidgets('a clean deck shows no violation line', (tester) async {
    await _pump(
      tester,
      _deck(
        steps: [
          {
            'elements': ['el-2'],
          },
        ],
      ),
    );
    expect(find.textContaining('inside a Stop'), findsNothing);
  });
}
