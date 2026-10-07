import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart'
    show EditorCanvas, EditorDocument, EditorInspector;
import 'package:fluvie_presenter/fluvie_presenter.dart' show FluvieSlides;
import 'package:obers_ui/obers_ui.dart' show OiIconButton, OiIcons;
import 'package:slides/editor/editor_screen.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_recents_store.dart';
import 'memory_start_prefs_store.dart';

/// The tips card never gets in the way of an editor journey.
MemoryStartPrefsStore _prefs() => MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true));

/// The phase-3 milestone: start from nothing, author a three-slide deck,
/// style it, and present it.
void main() {
  testWidgets('blank deck to presented, end to end', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(autosave: MemoryAutosaveStore(), recents: MemoryRecents(), startPrefs: _prefs()),
    );
    await tester.pump();

    // A fresh deck opens on an empty slide that invites an action.
    await tester.ensureVisible(find.text('New deck'));
    await tester.tap(find.text('New deck'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.textContaining('An empty slide'), findsOneWidget);

    // Drop a headline with the text tool and type into it.
    Offset at(double x, double y) {
      final canvas = tester.getRect(find.byType(EditorCanvas));
      const size = Size(1920, 1080);
      const margin = 48.0;
      final scale = math.min(
        (canvas.width - 2 * margin) / size.width,
        (canvas.height - 2 * margin) / size.height,
      );
      final origin = canvas.center - Offset(size.width / 2 * scale, size.height / 2 * scale);
      return origin + Offset(x, y) * scale;
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    await tester.tapAt(at(960, 400));
    await tester.pump();
    await tester.enterText(find.byType(EditableText).first, 'Built from nothing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    EditorDocument current() => tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
    final id = current().elementIdsInScene(0).single;
    expect(current().elementJson(id)!['text'], 'Built from nothing');

    // Style it through the inspector (still selected after the insert):
    // commit an exact font size and the document follows.
    final sizeField = find.descendant(
      of: find.byType(EditorInspector),
      matching: find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == '32',
      ),
    );
    expect(sizeField, findsOneWidget);
    await tester.enterText(sizeField, '72');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final styled = current().elementJson(id)!['style']! as Map<String, Object?>;
    expect(styled['fontSize'], 72.0);
    expect(styled['color'], '#F9FAFB', reason: 'the untouched style keys survive');

    // Grow the deck to three slides.
    await tester.tap(find.bySemanticsLabel('Add slide'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Duplicate slide'));
    await tester.pump();
    expect(current().sceneCount, 3);

    // Present, verify, and come back with everything intact.
    await tester.tap(find.text('Present'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);
    expect(
      find.descendant(of: find.byType(FluvieSlides), matching: find.text('Built from nothing')),
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
    expect(find.byType(FluvieSlides), findsNothing);
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(current().sceneCount, 3);
  });
}
