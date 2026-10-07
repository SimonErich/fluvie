import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas;
import 'package:slides/editor/demo_spec.dart';
import 'package:slides/loader/fluvie_file_saver.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_recents_store.dart';
import 'memory_start_prefs_store.dart';
import 'start_screen_robot.dart';

/// The tips card never gets in the way of an editor journey.
MemoryStartPrefsStore _prefs() => MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true));

/// A saver with no remembered target: the first save picks the name, like
/// a fresh demo deck on the desktop.
final class _PickingSaver implements FluvieFileSaver {
  final List<({String name, bool pickNew})> calls = [];

  @override
  String? targetPath;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    calls.add((name: suggestedName, pickNew: pickNew));
    targetPath = '/decks/demo.fluvie';
    return 'demo.fluvie';
  }

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async => null;

  @override
  Future<String?> saveCopyBytes({required String suggestedName, required List<int> bytes}) async =>
      null;

  @override
  Future<String?> saveBundle({
    required String suggestedName,
    required List<int> bytes,
    bool pickNew = false,
  }) async => null;
}

void main() {
  testWidgets('the start screen opens the demo deck in Edit mode and returns', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(autosave: MemoryAutosaveStore(), recents: MemoryRecents(), startPrefs: _prefs()),
    );
    await tester.pump();
    await openDemoForEdit(tester);
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next slide'));
    await tester.pump();
    expect(find.text('2 / 5'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Previous slide'));
    await tester.pump();
    expect(find.text('1 / 5'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pump();
    expect(find.byType(EditorCanvas), findsNothing);
    expect(find.text('Samples and tutorials'), findsOneWidget);
  });

  testWidgets('an edited demo deck saves through the name picker', (tester) async {
    useDesktopSurface(tester);
    final saver = _PickingSaver();
    final recents = MemoryRecents();
    await tester.pumpWidget(
      SlidesApp(
        saver: saver,
        recents: recents,
        autosave: MemoryAutosaveStore(),
        startPrefs: _prefs(),
      ),
    );
    await tester.pump();
    await openDemoForEdit(tester);
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);

    // An edit dirties the deck.
    await tester.tap(find.bySemanticsLabel('Add slide'));
    await tester.pump();
    expect(find.text('Unsaved'), findsOneWidget);

    // The first save has no remembered target, so the saver picks the
    // name; the title takes it, the dirty flag clears, and the deck gains
    // a recents identity.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saver.calls.single.name, 'Demo deck');
    expect(saver.calls.single.pickNew, isFalse);
    expect(find.text('demo.fluvie'), findsOneWidget);
    expect(find.text('Demo deck'), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
    expect(recents.entries.single.name, 'demo.fluvie');
    expect(recents.entries.single.path, '/decks/demo.fluvie');

    // Clean now: closing leaves without the discard guard.
    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorCanvas), findsNothing);
  });

  testWidgets('editing a picked .fluvie file opens the canvas', (tester) async {
    useDesktopSurface(tester);
    const good =
        '{"fluvieSpec": 1, "size": "hd", "fps": 30, "scenes": '
        '[{"duration": "60f", "children": [{"type": "Text", "text": "hi", '
        '"style": {"color": "#FFFFFF", "fontSize": 40}}]}]}';
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => parseFluvieJson('mine.fluvie', good),
        autosave: MemoryAutosaveStore(),
        startPrefs: _prefs(),
      ),
    );
    await tester.pump();
    await openDeckForEdit(tester);
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.text('mine.fluvie'), findsOneWidget);
  });

  test('the embedded demo spec parses and mirrors the repo demo', () {
    expect(demoSpecJson['fluvieSpec'], 1);
    expect(demoSpecJson['scenes']! as List, hasLength(5));
  });

  test('parseRawJson rejects non-object documents', () {
    expect(() => parseRawJson('[]'), throwsFormatException);
    expect(parseRawJson('{"scenes": []}'), isA<Map<String, Object?>>());
  });
}
