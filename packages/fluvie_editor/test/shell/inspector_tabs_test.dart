// The right column as a tab stack. A tab with no surface yet says what will
// fill it rather than showing a blank panel, and the workspace that owns a tab
// raises it so an author who picks Colour lands on grading.

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

Widget _tabs({
  EditorWorkspace workspace = EditorWorkspace.edit,
  Map<InspectorTab, Widget> panels = const {},
}) => OiApp(
  home: WorkspaceScope(
    workspace: workspace,
    child: InspectorTabs(inspector: const Text('the inspector'), panels: panels),
  ),
);

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('320px inspector keeps whole labels accessible at ${scale}x text', (tester) async {
      await tester.pumpWidget(
        OiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 500,
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const WorkspaceScope(
                  workspace: EditorWorkspace.edit,
                  child: InspectorTabs(inspector: Text('the inspector')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(InspectorTabs)).width, 320);
      for (final tab in InspectorTab.values) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(tab.label));
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: tab.label.length),
        );
        expect(boxes.map((box) => box.top).toSet(), hasLength(1), reason: tab.label);
      }

      final strip = find.byKey(const ValueKey('inspector-tab-strip'));
      expect(strip, findsOneWidget);
      await tester.drag(strip, const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Animation').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Animation'));
      await tester.pumpAndSettle();
      expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.animation)), findsOneWidget);

      // The component's keyboard navigation remains available after scrolling.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.audio)), findsOneWidget);
      expect(find.text('Audio').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(find.text('Inspector').hitTestable(), findsOneWidget);
      expect(find.text('the inspector'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Animation').hitTestable(), findsOneWidget);
      expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.animation)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('initial, workspace and timeline requests reveal their selected labels', (
    tester,
  ) async {
    Widget narrow({
      EditorWorkspace workspace = EditorWorkspace.edit,
      InspectorTab initial = InspectorTab.inspector,
      InspectorTabRequest? request,
      Key? key,
    }) => OiApp(
      home: Center(
        child: SizedBox(
          width: 320,
          height: 500,
          child: WorkspaceScope(
            workspace: workspace,
            child: InspectorTabs(
              key: key,
              inspector: const Text('the inspector'),
              initialTab: initial,
              request: request,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(narrow(initial: InspectorTab.animation));
    await tester.pumpAndSettle();
    expect(find.text('Animation').hitTestable(), findsOneWidget);

    await tester.pumpWidget(narrow(workspace: EditorWorkspace.quick));
    await tester.pumpAndSettle();
    expect(find.text('Inspector').hitTestable(), findsOneWidget);

    await tester.pumpWidget(narrow(workspace: EditorWorkspace.audio));
    await tester.pumpAndSettle();
    expect(find.text('Audio').hitTestable(), findsOneWidget);
    expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.audio)), findsOneWidget);

    await tester.pumpWidget(narrow(request: InspectorTabRequest(InspectorTab.animation)));
    await tester.pumpAndSettle();
    expect(find.text('Animation').hitTestable(), findsOneWidget);
    expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.animation)), findsOneWidget);

    // A request supplied on first mount is an explicit navigation intent too.
    await tester.pumpWidget(
      narrow(key: const ValueKey('fresh'), request: InspectorTabRequest(InspectorTab.animation)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Animation').hitTestable(), findsOneWidget);
    expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.animation)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens on the inspector', (tester) async {
    await tester.pumpWidget(_tabs());
    await tester.pumpAndSettle();

    expect(find.text('the inspector'), findsOneWidget);
  });

  testWidgets('offers every tab in a full workspace', (tester) async {
    await tester.pumpWidget(_tabs());
    await tester.pumpAndSettle();

    for (final tab in InspectorTab.values) {
      expect(find.text(tab.label), findsOneWidget, reason: '${tab.label} must be offered');
    }
  });

  testWidgets('Quick keeps only the inspector', (tester) async {
    // The other tabs are depth, and depth is what Quick exists to hide.
    await tester.pumpWidget(_tabs(workspace: EditorWorkspace.quick));
    await tester.pumpAndSettle();

    expect(find.text('Inspector'), findsOneWidget);
    for (final tab in InspectorTab.values.where((t) => t != InspectorTab.inspector)) {
      expect(find.text(tab.label), findsNothing, reason: '${tab.label} is depth');
    }
    expect(find.text('the inspector'), findsOneWidget, reason: 'and it still works');
  });

  testWidgets('a tab with no surface says what will fill it', (tester) async {
    await tester.pumpWidget(_tabs());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Effects'));
    await tester.pumpAndSettle();

    expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.effects)), findsOneWidget);
  });

  testWidgets('every placeholder says something, so none is a dead end', (tester) async {
    for (final tab in InspectorTab.values) {
      expect(InspectorTabPlaceholder.noteFor(tab), isNotEmpty, reason: tab.label);
    }
  });

  testWidgets('a surface that exists replaces its placeholder', (tester) async {
    await tester.pumpWidget(
      _tabs(panels: const {InspectorTab.audio: Text('the mixer')}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();

    expect(find.text('the mixer'), findsOneWidget);
    expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.audio)), findsNothing);
  });

  testWidgets('the Colour workspace raises the Colour tab', (tester) async {
    await tester.pumpWidget(_tabs(workspace: EditorWorkspace.colour));
    await tester.pumpAndSettle();

    expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.colour)), findsOneWidget);
  });

  testWidgets('the Audio workspace raises the Audio tab', (tester) async {
    await tester.pumpWidget(_tabs(workspace: EditorWorkspace.audio));
    await tester.pumpAndSettle();

    expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.audio)), findsOneWidget);
  });

  testWidgets('a workspace that owns no tab leaves the pick alone', (tester) async {
    await tester.pumpWidget(_tabs());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Animation'));
    await tester.pumpAndSettle();
    expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.animation)), findsOneWidget);

    // Deliver owns no tab, so the author's own choice stands.
    await tester.pumpWidget(_tabs(workspace: EditorWorkspace.deliver));
    await tester.pumpAndSettle();
    expect(find.text(InspectorTabPlaceholder.noteFor(InspectorTab.animation)), findsOneWidget);
  });

  test('only Colour and Audio own a tab', () {
    expect(InspectorTab.colour.workspace, EditorWorkspace.colour);
    expect(InspectorTab.audio.workspace, EditorWorkspace.audio);
    for (final tab in const [
      InspectorTab.inspector,
      InspectorTab.effects,
      InspectorTab.animation,
    ]) {
      expect(tab.workspace, isNull, reason: '${tab.label} is not a workspace');
    }
  });
}
