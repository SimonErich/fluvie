// The source monitor: scrub an asset, mark in and out, place the range. The
// marks belong to the asset, so marking once and placing three times gives
// three clips of the same range.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

MediaStoreEntry _clip({
  String? duration = '4s',
  double? fps = 30,
  int? inFrames,
  int? outFrames,
}) => MediaStoreEntry(
  id: 'm1',
  name: 'b-roll.mp4',
  kind: MediaStoreKind.video,
  source: const {'kind': 'file', 'value': '/media/b-roll.mp4'},
  duration: duration,
  fps: fps,
  inFrames: inFrames,
  outFrames: outFrames,
);

void main() {
  Future<({List<MediaStoreEntry> marked, List<SourceMonitorPlacement> placed, WidgetTester tester})>
  mount(WidgetTester tester, {MediaStoreEntry? entry, bool canPlace = true}) async {
    final marked = <MediaStoreEntry>[];
    final placed = <SourceMonitorPlacement>[];
    await tester.pumpWidget(
      OiApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 420,
            child: SourceMonitor(
              entry: entry ?? _clip(),
              onMarked: marked.add,
              onPlace: canPlace ? placed.add : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (marked: marked, placed: placed, tester: tester);
  }

  testWidgets('shows the asset and its transport', (tester) async {
    await mount(tester);

    expect(find.text('b-roll.mp4'), findsOneWidget);
    expect(find.byType(OiSlider), findsOneWidget);
    expect(find.text('Mark in'), findsOneWidget);
    expect(find.text('Mark out'), findsOneWidget);
  });

  testWidgets('an unprobed asset says why it cannot be scrubbed', (tester) async {
    // Better than an inert slider that pretends to work.
    await mount(tester, entry: _clip(duration: null, fps: null));

    expect(find.textContaining('never probed'), findsOneWidget);
    expect(find.byType(OiSlider), findsNothing);
    expect(find.text('Mark in'), findsNothing);
  });

  testWidgets('the position reads as timecode at the asset rate', (tester) async {
    await mount(tester, entry: _clip(fps: 25));

    expect(find.text('00:00:00:00'), findsOneWidget);
  });

  testWidgets('marking in reports the asset with the mark on it', (tester) async {
    final harness = await mount(tester);

    await tester.tap(find.text('Mark in'));
    await tester.pumpAndSettle();

    expect(harness.marked.single.inFrames, 0);
  });

  testWidgets('marking out at the head clears a stale in point', (tester) async {
    // An in point at or past the out is an inverted range, which is no range at
    // all. The author's intent — end here — is unambiguous, so the stale mark
    // gives way rather than the new one being refused.
    final harness = await mount(tester, entry: _clip(inFrames: 60));

    await tester.tap(find.text('Mark out'));
    await tester.pumpAndSettle();

    final result = harness.marked.single;
    expect(result.inFrames, isNull);
    expect(result.outFrames, 0);
  });

  testWidgets('clearing removes both marks', (tester) async {
    final harness = await mount(tester, entry: _clip(inFrames: 30, outFrames: 90));

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(harness.marked.single.inFrames, isNull);
    expect(harness.marked.single.outFrames, isNull);
  });

  testWidgets('the marked range is shown as timecode', (tester) async {
    await mount(tester, entry: _clip(inFrames: 30, outFrames: 90));

    expect(find.text('00:00:01:00 - 00:00:03:00'), findsOneWidget);
  });

  testWidgets('an unmarked asset still places, as its whole self', (tester) async {
    final harness = await mount(tester);

    await tester.tap(find.text('Place'));
    await tester.pumpAndSettle();

    expect(harness.placed.single.start, 0);
    expect(harness.placed.single.end, 120);
  });

  testWidgets('placing hands over the marked range', (tester) async {
    final harness = await mount(tester, entry: _clip(inFrames: 30, outFrames: 90));

    await tester.tap(find.text('Place'));
    await tester.pumpAndSettle();

    expect(harness.placed.single.start, 30);
    expect(harness.placed.single.end, 90);
    expect(harness.placed.single.entry.id, 'm1');
  });

  testWidgets('a host with nowhere to place offers the action disabled', (tester) async {
    final harness = await mount(tester, canPlace: false);

    await tester.tap(find.text('Place'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(harness.placed, isEmpty);
  });
}
