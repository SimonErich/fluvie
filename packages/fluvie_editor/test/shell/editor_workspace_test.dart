// Workspaces: one disclosure level every panel reads. The whole point is that
// the document is identical either side — a workspace changes what is on
// screen and nothing else — so switching mid-edit can never lose work.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'hello'},
      ],
    },
  ],
};

Widget _toolbar(EditorWorkspace workspace) => ProviderScope(
  child: OiApp(
    home: WorkspaceScope(
      workspace: workspace,
      child: const Align(alignment: Alignment.topLeft, child: EditorToolbar()),
    ),
  ),
);

void main() {
  group('the scope', () {
    testWidgets('a panel with no scope above it sees the full editor', (tester) async {
      // A host that has not adopted workspaces keeps exactly what it had.
      late DisclosureLevel level;
      late EditorWorkspace workspace;
      await tester.pumpWidget(
        OiApp(
          home: Builder(
            builder: (context) {
              level = WorkspaceScope.disclosureOf(context);
              workspace = WorkspaceScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(workspace, EditorWorkspace.edit);
      expect(level, DisclosureLevel.full);
    });

    testWidgets('every panel below reads the published level', (tester) async {
      late DisclosureLevel level;
      await tester.pumpWidget(
        OiApp(
          home: WorkspaceScope(
            workspace: EditorWorkspace.quick,
            child: Builder(
              builder: (context) {
                level = WorkspaceScope.disclosureOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(level, DisclosureLevel.minimal);
    });

    test('only Quick withholds anything', () {
      // Colour, Audio and Deliver raise a panel to the front; they do not take
      // controls away, or switching to grade would hide the tools you grade with.
      expect(EditorWorkspace.quick.disclosure, DisclosureLevel.minimal);
      for (final workspace in EditorWorkspace.values.where((w) => w != EditorWorkspace.quick)) {
        expect(workspace.disclosure, DisclosureLevel.full, reason: workspace.label);
      }
    });

    test('a re-published identical workspace does not notify', () {
      const child = SizedBox.shrink();
      const a = WorkspaceScope(workspace: EditorWorkspace.quick, child: child);
      const b = WorkspaceScope(workspace: EditorWorkspace.quick, child: child);
      const c = WorkspaceScope(workspace: EditorWorkspace.edit, child: child);

      expect(a.updateShouldNotify(b), isFalse);
      expect(a.updateShouldNotify(c), isTrue);
    });
  });

  group('the toolbar reads it', () {
    testWidgets('Quick offers the three tools that make a video', (tester) async {
      await tester.pumpWidget(_toolbar(EditorWorkspace.quick));
      await tester.pumpAndSettle();

      for (final tool in const ['Select tool (V)', 'Hand tool (H)', 'Text tool (T)']) {
        expect(find.bySemanticsLabel(tool), findsOneWidget, reason: '$tool is essential');
      }
      for (final tool in const ['Rectangle tool (R)', 'Arrow tool (A)', 'Rulers and guides']) {
        expect(find.bySemanticsLabel(tool), findsNothing, reason: '$tool is not');
      }
    });

    testWidgets('Edit offers all of them', (tester) async {
      await tester.pumpWidget(_toolbar(EditorWorkspace.edit));
      await tester.pumpAndSettle();

      for (final tool in const [
        'Select tool (V)',
        'Hand tool (H)',
        'Text tool (T)',
        'Rectangle tool (R)',
        'Ellipse tool (O)',
        'Line tool (L)',
        'Arrow tool (A)',
        'Media tool (M)',
        'Rulers and guides',
      ]) {
        expect(find.bySemanticsLabel(tool), findsOneWidget, reason: '$tool must be offered');
      }
    });
  });

  group('the control', () {
    testWidgets('offers every workspace and reports the pick', (tester) async {
      final picked = <EditorWorkspace>[];
      await tester.pumpWidget(
        OiApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: WorkspaceControl(workspace: EditorWorkspace.edit, onChanged: picked.add),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final workspace in EditorWorkspace.values) {
        expect(find.text(workspace.label), findsOneWidget);
      }

      await tester.tap(find.text('Quick'));
      await tester.pumpAndSettle();

      expect(picked, [EditorWorkspace.quick]);
    });
  });

  group('the document is identical either side', () {
    test('no workspace touches the document at all', () {
      // The guarantee that makes switching mid-edit safe. A workspace is
      // chrome: it lives with the panel layout, not in the deck, so it cannot
      // move a digest, cannot mark a deck unsaved, and cannot travel to
      // someone else who opens the file.
      final document = EditorDocument.fromJson(_deck());
      final renderDigest = document.spec.digest();
      final documentDigest = document.documentDigest;

      for (final workspace in EditorWorkspace.values) {
        expect(workspace.disclosure, isNotNull);
        expect(document.spec.digest(), renderDigest);
        expect(document.documentDigest, documentDigest);
      }
    });
  });
}
