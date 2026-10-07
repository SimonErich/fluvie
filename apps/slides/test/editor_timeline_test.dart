import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart'
    show EditorCanvas, TimelinePanel, TrackTimeline, slideStepBounds;
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

EditorCanvas _canvas(WidgetTester tester) => tester.widget<EditorCanvas>(find.byType(EditorCanvas));

/// Scrubs the shared ruler to +[dx] pixels of the lanes origin (the ruler
/// strip is the top 24px of the timeline, right of the 140px labels column).
Future<void> _scrubTo(WidgetTester tester, double dx) async {
  final ruler = tester.getTopLeft(find.byType(TrackTimeline)) + Offset(140 + dx, 12);
  final gesture = await tester.startGesture(ruler, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset.zero);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('the editor shows the timeline panel under the canvas', (tester) async {
    await _openDemo(tester);
    expect(find.byType(TimelinePanel), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.byType(TrackTimeline), findsOneWidget);
    // The panel sits below the canvas in the same column.
    final canvasBottom = tester.getBottomLeft(find.byType(EditorCanvas)).dy;
    final panelTop = tester.getTopLeft(find.byType(TimelinePanel)).dy;
    expect(panelTop, greaterThanOrEqualTo(canvasBottom));
  });

  testWidgets('the canvas and the ruler share one transport, frame-exactly', (tester) async {
    await _openDemo(tester);
    final transport = _canvas(tester).transport!;
    // A slide arrives settled: the shared playhead starts on the settle
    // frame, and the ruler agrees.
    expect(transport.frame, greaterThan(0));
    expect(
      tester.widget<TrackTimeline>(find.byType(TrackTimeline)).playhead,
      transport.frame.toDouble(),
    );

    // Scrub to frame 10 (40px at 4px/frame): canvas and ruler both land
    // exactly there.
    await _scrubTo(tester, 40);
    expect(transport.frame, 10);
    expect(tester.widget<TrackTimeline>(find.byType(TrackTimeline)).playhead, 10);

    // A slide change swaps the transport and arrives settled again.
    await tester.tap(find.bySemanticsLabel('Next slide'));
    await tester.pump();
    await tester.pump();
    final next = _canvas(tester).transport!;
    expect(identical(next, transport), isFalse);
    expect(next.frame, greaterThan(0));
  });

  testWidgets('Space with the panel open plays and pauses the slide', (tester) async {
    await _openDemo(tester);
    final transport = _canvas(tester).transport!;
    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(transport.isPlaying, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(transport.isPlaying, isFalse);
  });

  testWidgets('Space with the panel closed steps like a presenter', (tester) async {
    await _openDemo(tester);
    final document = _canvas(tester).document;
    final bounds = slideStepBounds(document, 0);
    expect(bounds, isNotEmpty);

    // Park the playhead before the first landing, then close the panel.
    await _scrubTo(tester, 8);
    expect(_canvas(tester).transport!.frame, lessThan(bounds.first));
    await tester.tap(find.bySemanticsLabel('Collapse the timeline'));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();

    // First press: seek to the next landing on this slide.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_canvas(tester).slide, 0);
    expect(_canvas(tester).transport!.frame, bounds.first);

    // Past the last landing: the next press moves to the next slide's base
    // landing.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump();
    expect(_canvas(tester).slide, 1);
    expect(_canvas(tester).transport!.frame, slideStepBounds(document, 1).first);
  });

  testWidgets('the timeline collapses from its header in the app tree', (tester) async {
    await _openDemo(tester);
    await tester.tap(find.bySemanticsLabel('Collapse the timeline'));
    await tester.pump();
    expect(find.byType(TrackTimeline), findsNothing);
    await tester.tap(find.bySemanticsLabel('Show the timeline'));
    await tester.pump();
    expect(find.byType(TrackTimeline), findsOneWidget);
  });
}
