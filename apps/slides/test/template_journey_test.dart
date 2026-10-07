import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart'
    show EditorCanvas, EditorDocumentMasters, EditorDocumentTheme;
import 'package:fluvie_presenter/fluvie_presenter.dart' show FluvieSlides;
import 'package:obers_ui/obers_ui.dart' show OiIconButton, OiIcons;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';
import 'package:slides/start/start_templates.dart';
import 'package:slides/templates/template_gallery.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_recents_store.dart';
import 'memory_start_prefs_store.dart';

/// The tips card never gets in the way of an editor journey.
MemoryStartPrefsStore _prefs() => MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true));

void main() {
  testWidgets('a new deck from a template opens, edits, and presents', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(autosave: MemoryAutosaveStore(), recents: MemoryRecents(), startPrefs: _prefs()),
    );
    await tester.pump();

    // The start screen offers the gallery; the gallery groups by purpose.
    await tester.ensureVisible(find.text('New from template'));
    await tester.tap(find.text('New from template'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateGalleryList), findsOneWidget);
    expect(find.text('Pitch'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);

    // Picking one opens the editor on the template's own deck. The strip
    // behind the dialog shows the same name, so scope the tap to the list.
    await tester.tap(
      find.descendant(of: find.byType(TemplateGalleryList), matching: find.text('Pitch deck')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.byType(EditorCanvas), findsOneWidget);
    final document = tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
    expect(document.sceneCount, greaterThanOrEqualTo(3));
    expect(document.sceneMasterName(0), isNotNull);
    // The template ships its own theme.
    expect(document.themeJson, isNotNull);

    // Present: the journey ends on the presented template content.
    await tester.tap(find.text('Present'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);
    expect(
      find.descendant(of: find.byType(FluvieSlides), matching: find.text('Your big idea')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(FluvieSlides),
        matching: find.byWidgetPredicate(
          (widget) => widget is OiIconButton && widget.icon == OiIcons.x,
        ),
      ),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.byType(EditorScreen), findsOneWidget);
  });

  testWidgets('cancelling the gallery stays on the start screen', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(autosave: MemoryAutosaveStore(), recents: MemoryRecents(), startPrefs: _prefs()),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('New from template'));
    await tester.tap(find.text('New from template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsNothing);
    expect(find.text('New from template'), findsOneWidget);
  });

  testWidgets('a template card on the strip starts its deck with no dialog', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(autosave: MemoryAutosaveStore(), recents: MemoryRecents(), startPrefs: _prefs()),
    );
    await tester.pump();

    final card = find.descendant(
      of: find.byType(StartTemplates),
      matching: find.text('Pitch deck'),
    );
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(TemplateGalleryList), findsNothing);
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.text('Pitch deck.fluvie'), findsOneWidget);
  });
}
