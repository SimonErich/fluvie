import 'dart:convert';

import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart' show OiListTile;
import 'package:slides/editor/editor_top_bar.dart';
import 'package:slides/editor/renamable_title.dart';
import 'package:slides/loader/fluvie_file_saver.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/recent_deck.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_recents_store.dart';
import 'memory_start_prefs_store.dart';
import 'start_screen_robot.dart';

/// The tips card never competes with the recents list under test.
MemoryStartPrefsStore _prefs() => MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true));

const Map<String, Object?> _spec = {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'type': 'Text',
          'text': 'hello',
          'style': {'color': '#FFFFFF', 'fontSize': 40},
        },
      ],
    },
  ],
};

final class _FakeSaver implements FluvieFileSaver {
  String? nextName;
  @override
  String? targetPath;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    if (nextName != null) targetPath = '/decks/$nextName';
    return nextName;
  }

  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async =>
      nextName;

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

LoadedDeck _loaded(String name, {String? path}) =>
    parseFluvieJson(name, jsonEncode(_spec), path: path);

Future<void> _closeEditor(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Close editor'));
  await tester.pumpAndSettle();
}

Finder _titleField() =>
    find.descendant(of: find.byType(RenamableTitle), matching: find.byType(EditableText));

void main() {
  testWidgets('opening a file lands it in recents; a recent entry reopens by path', (tester) async {
    useDesktopSurface(tester);
    final store = MemoryRecents();
    final opened = <String>[];
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => _loaded('mine.fluvie', path: '/decks/mine.fluvie'),
        openPath: (path) async {
          opened.add(path);
          return _loaded('mine.fluvie', path: path);
        },
        saver: _FakeSaver(),
        recents: store,
        autosave: MemoryAutosaveStore(),
        startPrefs: _prefs(),
      ),
    );
    await tester.pump();
    expect(find.text('No recent decks'), findsOneWidget);

    await openDeckForEdit(tester);
    expect(find.byType(EditorTopBar), findsOneWidget);
    expect(store.entries.single.name, 'mine.fluvie');
    expect(store.entries.single.path, '/decks/mine.fluvie');

    await _closeEditor(tester);
    expect(find.text('Recent decks'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(OiListTile, 'mine.fluvie'));
    await tester.tap(find.widgetWithText(OiListTile, 'mine.fluvie'));
    await tester.pump();
    await tester.pump();
    expect(opened, ['/decks/mine.fluvie']);
    expect(find.byType(EditorTopBar), findsOneWidget);
  });

  testWidgets('a rename updates the recents entry in place', (tester) async {
    useDesktopSurface(tester);
    final store = MemoryRecents();
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => _loaded('mine.fluvie', path: '/decks/mine.fluvie'),
        openPath: (path) async => _loaded('mine.fluvie', path: path),
        saver: _FakeSaver(),
        recents: store,
        autosave: MemoryAutosaveStore(),
        startPrefs: _prefs(),
      ),
    );
    await tester.pump();
    await openDeckForEdit(tester);

    await tester.tap(find.text('mine.fluvie'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('mine.fluvie'));
    await tester.pump();
    await tester.enterText(_titleField(), 'renamed.fluvie');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.entries.single.name, 'renamed.fluvie');
    expect(store.entries.single.path, '/decks/mine.fluvie');

    await _closeEditor(tester);
    expect(find.widgetWithText(OiListTile, 'renamed.fluvie'), findsOneWidget);
    expect(find.widgetWithText(OiListTile, 'mine.fluvie'), findsNothing);
  });

  testWidgets('saving a new deck records it; a rename before any identity does not', (
    tester,
  ) async {
    useDesktopSurface(tester);
    final store = MemoryRecents();
    final saver = _FakeSaver();
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => null,
        openPath: (path) async => _loaded('x.fluvie', path: path),
        saver: saver,
        recents: store,
        autosave: MemoryAutosaveStore(),
        startPrefs: _prefs(),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('New deck'));
    await tester.tap(find.text('New deck'));
    await tester.pump();
    await tester.pump();

    // A rename of a never-opened, never-saved deck has no identity to track.
    await tester.tap(find.text('untitled.fluvie'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('untitled.fluvie'));
    await tester.pump();
    await tester.enterText(_titleField(), 'fresh.fluvie');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(store.entries, isEmpty);

    saver.nextName = 'fresh.fluvie';
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.entries.single.name, 'fresh.fluvie');
    expect(store.entries.single.path, '/decks/fresh.fluvie');
  });

  testWidgets('a pathless entry shows as plain history, not a dead button', (tester) async {
    final store = MemoryRecents([RecentDeck(name: 'web.fluvie', lastOpened: DateTime(2026, 7))]);
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => null,
        openPath: (path) async => _loaded('web.fluvie'),
        saver: _FakeSaver(),
        recents: store,
        autosave: MemoryAutosaveStore(),
        startPrefs: _prefs(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Recent decks'), findsOneWidget);
    expect(find.text('web.fluvie'), findsOneWidget);
    expect(find.widgetWithText(OiListTile, 'web.fluvie'), findsNothing);
  });
}
