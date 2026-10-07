import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  testWidgets('Quick shows six essential rows and returning to Edit preserves the exact document', (
    tester,
  ) async {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'theme': {
        'typeScale': {
          'title': {'fontSize': 54, 'color': '#FF112233'},
        },
      },
      'scenes': [
        {
          'duration': '90f',
          'children': [
            {
              'id': 'title',
              'type': 'SplitText',
              'text': 'A title',
              'style': {'token': 'title'},
              'transform': {'x': .5, 'y': .5, 'w': .8, 'h': .2},
              'animate': [
                {'preset': 'fadeIn', 'duration': '30f'},
              ],
            },
          ],
        },
      ],
    });
    final history = DocumentHistory(document);
    final digest = document.renderDigest;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectionProvider.notifier).select({'title'});
    Future<void> show(EditorWorkspace workspace) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: OiApp(
            title: 'Quick',
            theme: OiThemeData.dark(),
            home: WorkspaceScope(
              workspace: workspace,
              child: EditorInspector(
                document: history.document,
                slide: 0,
                onCommand: history.dispatch,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    int rows() => tester
        .widgetList<OiPropertyGrid>(find.byType(OiPropertyGrid))
        .fold(0, (sum, grid) => sum + grid.properties.length);
    await show(EditorWorkspace.quick);
    expect(rows(), 6);
    expect(find.byType(AnimateSection), findsNothing);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Opacity'), findsOneWidget);
    final size = tester
        .widgetList<MathNumberInput>(find.byType(MathNumberInput))
        .firstWhere((input) => input.value == 54);
    size.onChanged(58);
    expect(history.document.elementJson('title')!['style'], {'token': 'title', 'fontSize': 58.0});
    history.undo();
    await show(EditorWorkspace.edit);
    expect(rows(), greaterThan(6));
    expect(find.byType(AnimateSection), findsOneWidget);
    expect(history.document.renderDigest, digest);
    expect(history.canUndo, isFalse);
    container.read(selectionProvider.notifier).select({});
    await show(EditorWorkspace.quick);
    expect(rows(), 6);
    expect(history.document.renderDigest, digest);
  });
}
