import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData, OiThemeScope;

/// The ruler-and-guide surface: rulers mount on request, a drag from a
/// ruler places a guide, guides drag to new positions, and dragging one
/// back onto its ruler removes it (the Figma gesture).
void main() {
  group('GuideLayer', () {
    List<ManualGuide>? committed;
    late CanvasViewportController viewport;

    Widget stage({List<ManualGuide> guides = const []}) {
      viewport = CanvasViewportController();
      return Directionality(
        textDirection: TextDirection.ltr,
        child: OiThemeScope(
          data: OiThemeData.dark(),
          child: Center(
            child: SizedBox(
              width: 320,
              height: 180,
              child: GuideLayer(
                viewport: viewport,
                slideSize: const Size(320, 180),
                guides: guides,
                onGuidesChanged: (guides) => committed = guides,
              ),
            ),
          ),
        ),
      );
    }

    setUp(() => committed = null);

    testWidgets('a drag from the left ruler places a vertical guide', (tester) async {
      await tester.pumpWidget(stage());
      final origin = tester.getTopLeft(find.byType(GuideLayer));
      final gesture = await tester.startGesture(origin + const Offset(12, 90));
      await gesture.moveTo(origin + const Offset(160, 90));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(committed, const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.5)]);
    });

    testWidgets('a drag from the top ruler places a horizontal guide', (tester) async {
      await tester.pumpWidget(stage());
      final origin = tester.getTopLeft(find.byType(GuideLayer));
      final gesture = await tester.startGesture(origin + const Offset(160, 12));
      await gesture.moveTo(origin + const Offset(160, 45));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(
        committed,
        const [ManualGuide(orientation: SnapOrientation.horizontal, position: 0.25)],
      );
    });

    testWidgets('a release still inside the ruler places nothing', (tester) async {
      await tester.pumpWidget(stage());
      final origin = tester.getTopLeft(find.byType(GuideLayer));
      final gesture = await tester.startGesture(origin + const Offset(12, 90));
      await gesture.moveTo(origin + const Offset(20, 90));
      await gesture.up();
      await tester.pump();
      expect(committed, isNull);
    });

    testWidgets('an existing guide drags to a new position', (tester) async {
      await tester.pumpWidget(
        stage(guides: const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.5)]),
      );
      final origin = tester.getTopLeft(find.byType(GuideLayer));
      final gesture = await tester.startGesture(origin + const Offset(160, 90));
      await gesture.moveTo(origin + const Offset(80, 90));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(committed, const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.25)]);
    });

    testWidgets('dragging a guide back onto its ruler removes it', (tester) async {
      await tester.pumpWidget(
        stage(guides: const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.5)]),
      );
      final origin = tester.getTopLeft(find.byType(GuideLayer));
      final gesture = await tester.startGesture(origin + const Offset(160, 90));
      await gesture.moveTo(origin + const Offset(10, 90));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(committed, isEmpty);
    });
  });

  group('the editor canvas wiring', () {
    Map<String, Object?> deck() => {
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'id': 'el-1',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.25, 'y': 0.5, 'w': 0.3, 'h': 0.4},
            },
          ],
        },
      ],
    };

    Future<(ProviderContainer, DocumentHistory)> pump(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final history = DocumentHistory(EditorDocument.fromJson(deck()));
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
                child: EditorCanvas(
                  document: history.document,
                  slide: 0,
                  viewportController: CanvasViewportController(),
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
      return (container, history);
    }

    testWidgets('rulers are off by default and mount on request', (tester) async {
      final (container, _) = await pump(tester);
      expect(find.byType(CanvasRuler), findsNothing);

      container.read(snapPreferencesProvider.notifier).toggleRulers();
      await tester.pump();
      expect(find.byType(CanvasRuler), findsNWidgets(2));
    });

    testWidgets('a ruler drag commits a guide through the command layer; undo removes it', (
      tester,
    ) async {
      final (container, history) = await pump(tester);
      container.read(snapPreferencesProvider.notifier).toggleRulers();
      await tester.pump();

      final origin = tester.getTopLeft(find.byType(EditorCanvas));
      final gesture = await tester.startGesture(origin + const Offset(12, 90));
      await gesture.moveTo(origin + const Offset(240, 90));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(
        ManualGuide.listFromJson(history.document.sceneMeta(0)['guides']),
        const [ManualGuide(orientation: SnapOrientation.vertical, position: 0.75)],
      );

      history.undo();
      expect(ManualGuide.listFromJson(history.document.sceneMeta(0)['guides']), isEmpty);
    });
  });
}
