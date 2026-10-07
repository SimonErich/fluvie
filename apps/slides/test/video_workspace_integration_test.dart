import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_recents_store.dart';
import 'memory_start_prefs_store.dart';
import 'start_screen_robot.dart';

void main() {
  testWidgets('video workspace selection reaches the editor panels', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(
        autosave: MemoryAutosaveStore(),
        recents: MemoryRecents(),
        startPrefs: MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true)),
      ),
    );
    await tester.pump();
    await openDemoForEdit(tester);
    await tester.tap(find.bySemanticsLabel('Video mode'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(VideoModePanel), findsOneWidget);
    tester.widget<WorkspaceControl>(find.byType(WorkspaceControl)).onChanged(EditorWorkspace.quick);
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<WorkspaceControl>(find.byType(WorkspaceControl)).workspace,
      EditorWorkspace.quick,
    );
    expect(WorkspaceScope.of(tester.element(find.byType(InspectorTabs))), EditorWorkspace.quick);
  });
  testWidgets('video mode retains the resizable shell and new media bin', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(
        autosave: MemoryAutosaveStore(),
        recents: MemoryRecents(),
        startPrefs: MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true)),
      ),
    );
    await tester.pump();
    await openDemoForEdit(tester);
    expect(find.byType(EditorShell), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Video mode'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EditorShell), findsOneWidget);
    expect(find.byType(MediaBinPanel), findsOneWidget);
  });
}
