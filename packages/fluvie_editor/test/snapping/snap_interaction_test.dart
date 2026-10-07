import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// The wire-through: dragging with snapping on adjusts the committed
/// placement; the bypass modifier (Ctrl) and the snapping preference switch
/// it off. The 320x180 slide puts el-left at LTWH(32, 54, 96, 72) and
/// el-right at LTWH(192, 54, 96, 72), a 64px gap edge to edge.
Map<String, Object?> _deck({List<ManualGuide> guides = const []}) => {
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
  if (guides.isNotEmpty)
    'editor': {
      'editorSchema': 1,
      'scenes': {
        '0': {'guides': ManualGuide.listToJson(guides)},
      },
    },
};

Future<(DocumentHistory, CanvasViewportController)> _pump(
  WidgetTester tester, {
  Map<String, Object?>? deck,
  ProviderContainer? container,
}) async {
  final scope = container ?? ProviderContainer();
  if (container == null) addTearDown(scope.dispose);
  final viewport = CanvasViewportController();
  final history = DocumentHistory(EditorDocument.fromJson(deck ?? _deck()));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 320,
            height: 180,
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
  return (history, viewport);
}

Offset _at(WidgetTester tester, CanvasViewportController viewport, Offset canvasPoint) =>
    tester.getTopLeft(find.byType(EditorCanvas)) + viewport.toViewport(canvasPoint);

double _x(DocumentHistory history, String id) =>
    ((history.document.elementJson(id)!['transform']! as Map<String, Object?>)['x']! as num)
        .toDouble();

void main() {
  testWidgets('a move inside tolerance lands edge-to-edge exactly', (tester) async {
    final (history, viewport) = await _pump(tester);
    // el-left's center, dragged 62px right: its right edge (190) is 2px from
    // el-right's left edge (192), inside the 6px tolerance.
    final start = _at(tester, viewport, const Offset(80, 90));
    await tester.tapAt(start);
    await tester.pump();
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(62, 0));
    await tester.pump();

    // Mid-drag the smart-guide overlay shows the active lines.
    final overlay = tester.widget<SnapGuideOverlay>(find.byType(SnapGuideOverlay));
    expect(overlay.lines, isNotEmpty);

    await gesture.up();
    await tester.pump();
    expect(_x(history, 'el-left'), 0.45, reason: 'right edge exactly on 192/320');
  });

  testWidgets('holding Ctrl bypasses the snap for a fine nudge', (tester) async {
    final (history, viewport) = await _pump(tester);
    final start = _at(tester, viewport, const Offset(80, 90));
    await tester.tapAt(start);
    await tester.pump();
    final gesture = await tester.startGesture(start);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await gesture.moveBy(const Offset(62, 0));
    await tester.pump();

    final overlay = tester.widget<SnapGuideOverlay>(find.byType(SnapGuideOverlay));
    expect(overlay.lines, isEmpty, reason: 'the bypass shows no lines');

    await gesture.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(_x(history, 'el-left'), closeTo(142 / 320, 1e-9));
  });

  testWidgets('the snapping preference switches the engine off entirely', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(snapPreferencesProvider.notifier).toggleSnapping();
    final (history, viewport) = await _pump(tester, container: container);
    final start = _at(tester, viewport, const Offset(80, 90));
    await tester.tapAt(start);
    await tester.pump();
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(62, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(_x(history, 'el-left'), closeTo(142 / 320, 1e-9));
  });

  testWidgets('a manual guide from the document snaps the drag', (tester) async {
    final (history, viewport) = await _pump(
      tester,
      deck: _deck(
        guides: const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.5)],
      ),
    );
    // Dragged 78px right, el-left's center (158) is 2px from the guide (160).
    final start = _at(tester, viewport, const Offset(80, 90));
    await tester.tapAt(start);
    await tester.pump();
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(78, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(_x(history, 'el-left'), 0.5);
  });

  testWidgets('a hidden element offers no candidate lines', (tester) async {
    final (history, viewport) = await _pump(tester);
    history.dispatch(const SetElementsVisibleCommand(ids: ['el-right'], visible: false));
    await tester.pump();
    // Rebuild the canvas over the annotated document.
    await _pumpExisting(tester, history, viewport);
    final start = _at(tester, viewport, const Offset(80, 90));
    await tester.tapAt(start);
    await tester.pump();
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(62, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(_x(history, 'el-left'), closeTo(142 / 320, 1e-9), reason: 'nothing to snap to');
  });

  testWidgets('a resize inside tolerance lands the dragged edge exactly', (tester) async {
    final (history, viewport) = await _pump(tester);
    final center = _at(tester, viewport, const Offset(80, 90));
    await tester.tapAt(center);
    await tester.pump();
    // el-left's right-edge handle sits at canvas (128, 90); drag it to 190,
    // 2px short of el-right's left edge (192).
    final handle = _at(tester, viewport, const Offset(128, 90));
    final gesture = await tester.startGesture(handle);
    await gesture.moveBy(const Offset(62, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    final transform =
        history.document.elementJson('el-left')!['transform']! as Map<String, Object?>;
    expect((transform['w']! as num).toDouble(), 0.5, reason: 'width 160/320, edge on 192');
    expect((transform['x']! as num).toDouble(), 0.35);
  });
}

/// Re-pumps the canvas over [history]'s current document.
Future<void> _pumpExisting(
  WidgetTester tester,
  DocumentHistory history,
  CanvasViewportController viewport,
) async {
  final scopeContainer = ProviderScope.containerOf(
    tester.element(find.byType(EditorCanvas)),
    listen: false,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scopeContainer,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 320,
            height: 180,
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
}
