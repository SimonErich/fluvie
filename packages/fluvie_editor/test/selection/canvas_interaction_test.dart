import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/selection/selection_chrome.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

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

Future<(ProviderContainer, CanvasViewportController)> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final viewport = CanvasViewportController();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiThemeScope(
        data: OiThemeData.dark(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 320,
              height: 180,
              child: EditorCanvas(
                document: EditorDocument.fromJson(_deck()),
                slide: 0,
                viewportController: viewport,
                fitMargin: 0,
                interactive: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (container, viewport);
}

/// The viewport point over canvas fraction ([fx], [fy]).
Offset _at(WidgetTester tester, CanvasViewportController viewport, double fx, double fy) =>
    tester.getTopLeft(find.byType(EditorCanvas)) + viewport.toViewport(Offset(320 * fx, 180 * fy));

void main() {
  testWidgets('clicking an element selects it; empty canvas clears', (tester) async {
    final (container, viewport) = await _pump(tester);
    await tester.tapAt(_at(tester, viewport, 0.25, 0.5));
    await tester.pump();
    expect(container.read(selectionProvider), {'el-left'});

    await tester.tapAt(_at(tester, viewport, 0.75, 0.5));
    await tester.pump();
    expect(container.read(selectionProvider), {'el-right'});

    await tester.tapAt(_at(tester, viewport, 0.5, 0.05));
    await tester.pump();
    expect(container.read(selectionProvider), isEmpty);
  });

  testWidgets('shift-click extends the selection', (tester) async {
    final (container, viewport) = await _pump(tester);
    await tester.tapAt(_at(tester, viewport, 0.25, 0.5));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(_at(tester, viewport, 0.75, 0.5));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(container.read(selectionProvider), {'el-left', 'el-right'});
  });

  testWidgets('a drag on empty canvas marquees; Escape clears', (tester) async {
    final (container, viewport) = await _pump(tester);
    final gesture = await tester.startGesture(_at(tester, viewport, 0.02, 0.05));
    await gesture.moveTo(_at(tester, viewport, 0.98, 0.95));
    await tester.pump();
    // Mid-drag the marquee is visible.
    expect(find.byType(MarqueeOverlay), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(container.read(selectionProvider), {'el-left', 'el-right'});

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(container.read(selectionProvider), isEmpty);
  });

  testWidgets('a selected element shows its bounding box; hover outlines', (tester) async {
    final (container, viewport) = await _pump(tester);
    expect(find.byType(SelectionChrome), findsOneWidget);
    await tester.tapAt(_at(tester, viewport, 0.25, 0.5));
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(_at(tester, viewport, 0.75, 0.5));
    await tester.pump();
    final chrome = tester.widget<SelectionChrome>(find.byType(SelectionChrome));
    expect(chrome.selected, {'el-left'});
    expect(chrome.hovered, 'el-right');
  });
}
