import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show MediaFileBase;
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:obers_ui/obers_ui.dart' show OiFileDropTarget, OiIconButton, OiIcons;
import 'package:slides/editor/editor_screen.dart' show EditorScreen;
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/routing/speaker_route.dart';
import 'package:slides/slides_app.dart';
import 'package:slides/speaker_app.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_recents_store.dart';
import 'memory_start_prefs_store.dart';
import 'start_screen_robot.dart';

/// The shell with both remembered lists faked, so no test reads the
/// developer's config directory and the layout is deterministic.
MemoryStartPrefsStore _prefs() => MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true));

void main() {
  testWidgets('boots to the start screen', (tester) async {
    await tester.pumpWidget(SlidesApp(recents: MemoryRecents(), startPrefs: _prefs()));
    await tester.pump();
    expect(find.text('fluvie slides'), findsOneWidget);
    expect(find.text('New deck'), findsOneWidget);
    expect(find.text('Open a deck'), findsOneWidget);
    expect(find.text('Samples and tutorials'), findsOneWidget);
    // The sample decks are behind the samples dialog, not on the screen.
    expect(find.text('Plain slides'), findsNothing);
    expect(find.text('The full talk'), findsNothing);
    // The start screen is also a drop target for .fluvie files.
    expect(find.byType(OiFileDropTarget), findsOneWidget);
  });

  testWidgets('picking a sample presents it, and X returns to the start screen', (tester) async {
    await tester.pumpWidget(SlidesApp(recents: MemoryRecents(), startPrefs: _prefs()));
    await tester.pump();
    await openSamples(tester);
    await tester.tap(find.text('Plain slides'));
    // The dialog fades out, then its future hands the deck to the shell.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('fluvie slides'), findsWidgets);

    await tester.tap(
      find.byWidgetPredicate((w) => w is OiIconButton && w.icon == OiIcons.x),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.byType(FluvieSlides), findsNothing);
    expect(find.text('Samples and tutorials'), findsOneWidget);
  });

  testWidgets('opening a file presents it; a broken file shows the error', (tester) async {
    const good =
        '{"fluvieSpec": 1, "size": "hd", "fps": 30, "scenes": '
        '[{"duration": "60f", "children": [{"type": "Text", "text": "hi", '
        '"style": {"color": "#FFFFFF", "fontSize": 40}}]}]}';
    var next = parseFluvieJson('good.fluvie', good);
    await tester.pumpWidget(
      SlidesApp(openFile: () async => next, recents: MemoryRecents(), startPrefs: _prefs()),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Present a .fluvie file'));
    await tester.tap(find.text('Present a .fluvie file'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(
      find.byWidgetPredicate((w) => w is OiIconButton && w.icon == OiIcons.x),
      warnIfMissed: false,
    );
    await tester.pump();
    next = parseFluvieJson('broken.fluvie', '{not json');
    await tester.ensureVisible(find.text('Present a .fluvie file'));
    await tester.tap(find.text('Present a .fluvie file'));
    await tester.pump();
    expect(find.byType(FluvieSlides), findsNothing);
    expect(find.textContaining('broken.fluvie'), findsOneWidget);
  });

  testWidgets('editing clears the media base on close, and a blank deck never sets it', (
    tester,
  ) async {
    useDesktopSurface(tester);
    addTearDown(() => MediaFileBase.current = null);
    const deck =
        '{"fluvieSpec":1,"size":"hd","fps":30,"scenes":[{"duration":"60f","children":[]}]}';
    Future<LoadedDeck> openFileDeck() =>
        parseFluvieBytes('deck.fluvie', utf8.encode(deck), path: '/decks/launch/deck.fluvie');

    await tester.pumpWidget(
      SlidesApp(
        openFile: openFileDeck,
        autosave: MemoryAutosaveStore(),
        recents: MemoryRecents(),
        startPrefs: _prefs(),
      ),
    );
    await tester.pump();

    // Editing a file deck scopes the media base to the document's folder.
    await openDeckForEdit(tester);
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(MediaFileBase.current, '/decks/launch');

    // Closing back to the start screen clears the scope.
    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsNothing);
    expect(MediaFileBase.current, isNull);

    // A blank deck has no document folder: opening it clears any base a prior
    // file deck left lingering, so its relative media never mis-resolve.
    MediaFileBase.current = '/decks/launch';
    await tester.ensureVisible(find.text('New deck'));
    await tester.tap(find.text('New deck'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(MediaFileBase.current, isNull);
  });

  testWidgets('the speaker shell resolves a bundled deck, a file, and the unknowns', (
    tester,
  ) async {
    await tester.pumpWidget(SpeakerApp(readDeck: () => (kind: 'bundled', payload: 'welcome')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FluvieSpeaker), findsOneWidget);

    await tester.pumpWidget(SpeakerApp(readDeck: () => (kind: 'bundled', payload: 'nope')));
    await tester.pump();
    expect(find.textContaining('Unknown deck'), findsOneWidget);

    final json = jsonEncode({
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Text',
              'text': 'hi',
              'style': {'color': '#FFFFFF', 'fontSize': 40},
            },
          ],
        },
      ],
    });
    await tester.pumpWidget(SpeakerApp(readDeck: () => (kind: 'file', payload: json)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FluvieSpeaker), findsOneWidget);

    await tester.pumpWidget(SpeakerApp(readDeck: () => (kind: 'file', payload: '{broken')));
    await tester.pump();
    expect(find.textContaining('no longer parses'), findsOneWidget);
  });

  testWidgets('off the web there is no speaker route, and the speaker shell says so', (
    tester,
  ) async {
    expect(isSpeakerRoute(), isFalse);
    expect(readSpeakerDeck(), isNull);
    await tester.pumpWidget(const SpeakerApp());
    await tester.pump();
    expect(find.textContaining('Nothing is being presented yet'), findsOneWidget);
  });
}
