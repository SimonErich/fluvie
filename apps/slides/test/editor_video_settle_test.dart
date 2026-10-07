import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas, VideoTimebase;
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

// Scene 0 carries a 12-frame entrance (settles at 12); scene 1 arrives on an
// overlapping slide enter (span start 45, blend ends and it settles at 60).
const _transitionDeck =
    '{"fluvieSpec": 1, "size": {"width": 320, "height": 180}, "fps": 30, '
    '"scenes": [ '
    '{"duration": "60f", "children": [{"type": "Text", "text": "one", '
    '"animate": [{"preset": "fadeIn", "duration": "12f"}]}]}, '
    '{"duration": "60f", "enter": {"kind": "slide", "duration": "15f"}, '
    '"children": [{"type": "Text", "text": "two"}]}]}';

Future<void> _openTransitionDeck(WidgetTester tester) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    SlidesApp(
      openFile: () async => parseFluvieJson('transition.fluvie', _transitionDeck),
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
  testWidgets('entering video mode parks on the current scene settled frame', (tester) async {
    await _openTransitionDeck(tester);
    await _enterVideoMode(tester);
    final canvas = _canvas(tester);
    final timebase = VideoTimebase.of(canvas.document);
    // Scene 0's 12-frame entrance means the settled frame is 12, not 0 —
    // frame 0 would show the scene mid-entrance.
    expect(timebase.settleFrameOf(0), 12);
    expect(canvas.transport!.frame, 12);
  });

  testWidgets('the stepper seeks the settled frame, past the transition', (tester) async {
    await _openTransitionDeck(tester);
    await _enterVideoMode(tester);
    final transport = _canvas(tester).transport!;
    final timebase = VideoTimebase.of(_canvas(tester).document);
    expect(timebase.settleFrameOf(1), 60);
    expect(timebase.sceneSpans[1].start, 45);

    await tester.tap(find.bySemanticsLabel('Next slide'));
    await tester.pump();
    await tester.pump();
    // Not the span start 45 (mid-blend), but the settled frame 60.
    expect(transport.frame, 60);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('onShowSlide seeks the settled frame of the shown scene', (tester) async {
    await _openTransitionDeck(tester);
    await _enterVideoMode(tester);
    final canvas = _canvas(tester);
    final transport = canvas.transport!;

    canvas.onShowSlide!(1);
    await tester.pump();
    await tester.pump();
    expect(transport.frame, 60);
  });
}
