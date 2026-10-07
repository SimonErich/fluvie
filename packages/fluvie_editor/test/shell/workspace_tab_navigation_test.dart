import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  for (final workspace in [EditorWorkspace.colour, EditorWorkspace.audio]) {
    testWidgets('${workspace.name} lets the user switch to Inspector', (tester) async {
      await tester.pumpWidget(
        OiApp(
          home: WorkspaceScope(
            workspace: workspace,
            child: const InspectorTabs(inspector: Text('Inspector content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspector'));
      await tester.pumpAndSettle();
      expect(find.text('Inspector content'), findsOneWidget);
    });
  }
}
