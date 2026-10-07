import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart'
    show
        AudioTrackSection,
        EditorCanvas,
        EditorDocumentMedia,
        SlideStrip,
        TimelinePanel,
        TrackTimeline,
        VideoModePanel,
        VideoTimebase;
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

const _audioDeck =
    '{"fluvieSpec": 1, "size": {"width": 320, "height": 180}, "fps": 30, '
    '"audio": [{"kind": "music", "source": {"kind": "asset", "value": "audio/bed.mp3"}}], '
    '"scenes": [ '
    '{"duration": "120f", "children": [{"type": "Text", "text": "one"}]}, '
    '{"duration": "90f", "children": [{"type": "Text", "text": "two"}]}]}';

Future<void> _openDemo(WidgetTester tester) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    SlidesApp(autosave: MemoryAutosaveStore(), recents: MemoryRecents(), startPrefs: _prefs()),
  );
  await tester.pump();
  await openDemoForEdit(tester);
}

Future<void> _openAudioDeck(WidgetTester tester) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    SlidesApp(
      openFile: () async => parseFluvieJson('audio.fluvie', _audioDeck),
      autosave: MemoryAutosaveStore(),
      recents: MemoryRecents(),
      startPrefs: _prefs(),
    ),
  );
  await tester.pump();
  await openDeckForEdit(tester);
}

EditorCanvas _canvas(WidgetTester tester) => tester.widget<EditorCanvas>(find.byType(EditorCanvas));

Future<void> _enterVideoMode(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Video mode'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the top bar toggle swaps the whole surface and the document remembers', (
    tester,
  ) async {
    await _openDemo(tester);
    expect(find.byType(TimelinePanel), findsOneWidget);
    expect(find.byType(SlideStrip), findsOneWidget);

    await _enterVideoMode(tester);
    expect(find.byType(VideoModePanel), findsOneWidget);
    expect(find.byType(TimelinePanel), findsNothing);
    expect(find.byType(SlideStrip), findsNothing);
    // The media store panel takes the left side.
    expect(find.text('Assets'), findsOneWidget);
    final canvas = _canvas(tester);
    expect(canvas.wholeDocument, isTrue);
    expect(canvas.document.deckMeta['mode'], 'video');

    await tester.tap(find.bySemanticsLabel('Slides mode'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TimelinePanel), findsOneWidget);
    expect(find.byType(VideoModePanel), findsNothing);
    expect(_canvas(tester).wholeDocument, isFalse);
    expect(_canvas(tester).document.deckMeta['mode'], 'slides');
  });

  testWidgets('the mode switch is one undoable step', (tester) async {
    await _openDemo(tester);
    await _enterVideoMode(tester);
    expect(find.byType(VideoModePanel), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(VideoModePanel), findsNothing);
    expect(find.byType(TimelinePanel), findsOneWidget);
    expect(_canvas(tester).document.deckMeta.containsKey('mode'), isFalse);
  });

  testWidgets('the additive law: a slides-only session never writes the mode key', (tester) async {
    await _openDemo(tester);
    await tester.tap(find.bySemanticsLabel('Next slide'));
    await tester.pump();
    final document = _canvas(tester).document;
    expect(document.deckMeta.containsKey('mode'), isFalse);
    expect(document.toJson()['editor'].toString(), isNot(contains('mode')));
  });

  testWidgets('one clock: the canvas crosses scene boundaries and the chrome follows', (
    tester,
  ) async {
    await _openAudioDeck(tester);
    await _enterVideoMode(tester);
    Finder onStage(String text) =>
        find.descendant(of: find.byType(EditorCanvas), matching: find.text(text));
    expect(onStage('one'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    final transport = _canvas(tester).transport!;
    final timebase = VideoTimebase.of(_canvas(tester).document);
    expect(transport.length, timebase.totalFrames);

    // Seek across the boundary: the stage shows scene two at its local
    // frame, and the interactive layer follows the playhead's scene.
    transport.seek(130);
    await tester.pump();
    await tester.pump();
    expect(onStage('two'), findsOneWidget);
    expect(onStage('one'), findsNothing);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(_canvas(tester).slide, 1);
    expect(transport.frame - timebase.sceneSpans[1].start, 10);
  });

  testWidgets('the slide stepper seeks scene starts on the shared clock', (tester) async {
    await _openAudioDeck(tester);
    await _enterVideoMode(tester);
    final transport = _canvas(tester).transport!;
    await tester.tap(find.bySemanticsLabel('Next slide'));
    await tester.pump();
    await tester.pump();
    expect(transport.frame, 120);
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Previous slide'));
    await tester.pump();
    await tester.pump();
    expect(transport.frame, 0);
  });

  testWidgets('tapping an audio lane opens the audio inspector on the right', (tester) async {
    await _openAudioDeck(tester);
    await _enterVideoMode(tester);
    expect(find.byType(AudioTrackSection), findsNothing);
    // The music lane is row 2 of the timeline (scenes, then the bed).
    final lanes = tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 24);
    await tester.tapAt(lanes + const Offset(100, 42));
    await tester.pump();
    expect(find.byType(AudioTrackSection), findsOneWidget);
    expect(find.text('bed.mp3'), findsWidgets);
  });
}
