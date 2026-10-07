import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas, NotesEditor, TimelinePanel;
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_recents_store.dart';
import 'memory_start_prefs_store.dart';
import 'start_screen_robot.dart';

/// The tips card never gets in the way of an editor journey.
MemoryStartPrefsStore _prefs() => MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true));

Future<void> _openDemo(WidgetTester tester) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    SlidesApp(autosave: MemoryAutosaveStore(), recents: MemoryRecents(), startPrefs: _prefs()),
  );
  await tester.pump();
  await openDemoForEdit(tester);
}

void main() {
  testWidgets('the notes strip sits under the timeline panel', (tester) async {
    await _openDemo(tester);
    expect(find.byType(NotesEditor), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    final timelineTop = tester.getTopLeft(find.byType(TimelinePanel)).dy;
    final notesTop = tester.getTopLeft(find.byType(NotesEditor)).dy;
    expect(notesTop, greaterThan(timelineTop));
  });

  testWidgets('a note typed in the strip lands in the document', (tester) async {
    await _openDemo(tester);
    await tester.tap(find.bySemanticsLabel('Show the notes editor'));
    await tester.pump();
    final field = find.descendant(
      of: find.byKey(const ValueKey('note-text')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'Open with the story.');
    await tester.pump();
    tester.widget<EditableText>(field).focusNode.unfocus();
    await tester.pump();
    await tester.pump();
    final document = tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
    expect(document.sceneJson(0)['notes'], {'text': 'Open with the story.'});
  });
}
