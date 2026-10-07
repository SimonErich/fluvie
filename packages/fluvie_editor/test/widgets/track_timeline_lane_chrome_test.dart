// Per-lane height, the lock/mute/solo affordances, label reordering, and the
// filmstrip request. Everything here is host state the widget paints and host
// intention the widget reports; it decides none of it.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

// The harness centers a 620x220 timeline on the 800x600 test surface: lanes
// start at global x 230, the ruler band is y 190..214, and the rows follow
// from y 214 at whatever height each one asks for.
const double _lanesTop = 214;
const _green = Color(0xFF2ECC8F);

/// Row 0 is 28 tall (the default), row 1 asks for 60, row 2 is 28 again.
List<TimelineTrack> _tracks() => const [
  TimelineTrack(
    id: 't1',
    label: 'Video 1',
    bars: [TimelineBar(id: 'a', start: 10, end: 40, color: _green)],
  ),
  TimelineTrack(
    id: 't2',
    label: 'Audio 1',
    height: 60,
    bars: [TimelineBar(id: 'b', start: 10, end: 40, color: _green)],
  ),
  TimelineTrack(id: 't3', label: 'Video 2'),
];

final class _Log {
  final List<String> tapped = [];
  final List<String> locked = [];
  final List<String> muted = [];
  final List<String> soloed = [];
  final List<({String id, int row})> reordered = [];
  final List<({int from, int to})> filmstrips = [];
}

Widget _harness(
  _Log log, {
  List<TimelineTrack>? tracks,
  bool chrome = true,
  bool filmstrip = true,
  TrackTimelineController? controller,
}) => OiThemeScope(
  data: OiThemeData.dark(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 620,
        height: 220,
        child: TrackTimeline(
          tracks: tracks ?? _tracks(),
          fps: 30,
          totalFrames: 300,
          controller: controller,
          navigation: TrackTimelineNavigation(
            onBarTapped: (id, {required additive}) => log.tapped.add(id),
          ),
          lanes: TrackTimelineLaneActions(
            onLaneLockToggled: chrome ? log.locked.add : null,
            onLaneMuteToggled: chrome ? log.muted.add : null,
            onLaneSoloToggled: chrome ? log.soloed.add : null,
            onLaneReordered: chrome ? (id, row) => log.reordered.add((id: id, row: row)) : null,
          ),
          onFilmstripNeeded: filmstrip
              ? (from, to) => log.filmstrips.add((from: from, to: to))
              : null,
        ),
      ),
    ),
  ),
);

void main() {
  group('a lane that asks for its own height', () {
    testWidgets('takes it, and pushes the rows below it down', (tester) async {
      // Row 1 is 60 tall, so row 2 starts at 214 + 28 + 60 and a tap there
      // has to reach the third lane's bar, not the second's.
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await tester.tapAt(const Offset(300, _lanesTop + 28 + 30));
      await tester.pump();

      expect(log.tapped, ['b'], reason: 'the tall row still holds its own bar at +58');
    });

    testWidgets('leaves the rows above it exactly where they were', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await tester.tapAt(const Offset(300, _lanesTop + 14));
      await tester.pump();

      expect(log.tapped, ['a']);
    });
  });

  group('the lane affordances', () {
    testWidgets('report the lane they belong to', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await tester.tap(find.bySemanticsLabel('Lock Audio 1'));
      await tester.tap(find.bySemanticsLabel('Mute Audio 1'));
      await tester.tap(find.bySemanticsLabel('Solo Audio 1'));
      await tester.pump();

      expect(log.locked, ['t2']);
      expect(log.muted, ['t2']);
      expect(log.soloed, ['t2']);
    });

    testWidgets('are absent where the host cannot serve them', (tester) async {
      // An affordance nothing answers is worse than no affordance: it looks
      // live and does nothing.
      final log = _Log();
      await tester.pumpWidget(_harness(log, chrome: false));

      expect(find.bySemanticsLabel('Lock Audio 1'), findsNothing);
    });
  });

  group('dragging a label', () {
    testWidgets('reports the row it landed on', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      // From the first row's label, down past the 28 and 60 tall rows.
      await tester.drag(find.text('Video 1'), const Offset(0, 100));
      await tester.pump();

      expect(log.reordered.single, (id: 't1', row: 2));
    });

    testWidgets('reports nothing when it never left its own row', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await tester.drag(find.text('Video 1'), const Offset(0, 4));
      await tester.pump();

      expect(log.reordered, isEmpty);
    });

    testWidgets('clamps to the last row rather than falling off the end', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await tester.drag(find.text('Video 1'), const Offset(0, 5000));
      await tester.pump();

      expect(log.reordered.single.row, 2);
    });
  });

  group('the filmstrip request', () {
    testWidgets('asks only for the frames the lanes can show', (tester) async {
      // 480 pixels of lane at the default 4 px/frame is 120 frames, and the
      // timeline is 300 long: asking for all of it would decode two and a
      // half screens nobody is looking at.
      final log = _Log();
      await tester.pumpWidget(_harness(log));
      await tester.pump();

      expect(log.filmstrips.single.from, 0);
      expect(log.filmstrips.single.to, lessThan(130));
    });

    testWidgets('asks again when the zoom changes what is on screen', (tester) async {
      final log = _Log();
      // Explicitly at the default zoom, so the change below is the only thing
      // that moves.
      final controller = TrackTimelineController(pixelsPerFrame: double.parse('4'));
      addTearDown(controller.dispose);
      await tester.pumpWidget(_harness(log, controller: controller));
      await tester.pump();
      final first = log.filmstrips.single;

      controller.pixelsPerFrame = 2;
      await tester.pump();
      await tester.pump();

      expect(log.filmstrips, hasLength(2));
      expect(log.filmstrips.last.to, greaterThan(first.to));
    });

    testWidgets('never asks twice for the same span', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));
      await tester.pump();
      await tester.pumpWidget(_harness(log));
      await tester.pump();

      expect(log.filmstrips, hasLength(1), reason: 'a host that heard it twice would decode twice');
    });

    testWidgets('stays quiet where no host is listening', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log, filmstrip: false));
      await tester.pump();

      expect(log.filmstrips, isEmpty);
    });
  });
}
