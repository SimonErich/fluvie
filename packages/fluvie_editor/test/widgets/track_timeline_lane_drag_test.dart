// Dragging a bar to another lane. The widget stays domain-free: it names the
// lane the pointer is over and never moves the bar itself, so a host that
// cannot re-lane simply ignores the id it is handed.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

// The harness centers a 620x220 timeline on the 800x600 test surface, so
// with the default label column (140), ruler (24), and zoom (4 px/frame):
// lanes start at global x 230, the ruler band is y 190..214, and track row
// N occupies y 214+28N..242+28N. Bar b1 (frames 10..40) paints at x 270..390.
const double _row0Y = 228;
const double _row1Y = 256;
const double _row2Y = 284;

const _green = Color(0xFF2ECC8F);

List<TimelineTrack> _tracks() => const [
  TimelineTrack(
    id: 't1',
    label: 'Video 1',
    bars: [TimelineBar(id: 'b1', start: 10, end: 40, color: _green)],
  ),
  TimelineTrack(
    id: 't2',
    label: 'Video 2',
    bars: [TimelineBar(id: 'b2', start: 10, end: 40, color: _green)],
  ),
  TimelineTrack(id: 't3', label: 'Video 3'),
];

final class _Log {
  final List<String> lanes = [];
  final List<double> starts = [];
  (double, double)? resized;
}

Widget _harness(_Log log, {List<TimelineTrack>? tracks, double? snapFrame}) => OiThemeScope(
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
          playhead: 60,
          snapFrame: snapFrame,
          edit: TrackTimelineEditActions(
            onBarMoved: (id, newStart, targetTrackId) {
              log.lanes.add(targetTrackId);
              log.starts.add(newStart);
            },
            onBarResized: (id, newStart, newEnd) => log.resized = (newStart, newEnd),
          ),
        ),
      ),
    ),
  ),
);

/// Drags from [from] through each of [waypoints] in turn, pumping between.
///
/// The first move is a two-pixel nudge along the drag axis, because a
/// horizontal recognizer reports the pointer's true position only once it has
/// won the arena: the update that accepts the drag is corrected onto the axis
/// by design, so a lane change on that one event could never be seen. A real
/// pointer emits a stream of moves and crosses this in the first millimetre.
Future<void> _dragThrough(WidgetTester tester, Offset from, List<Offset> waypoints) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveTo(from + const Offset(2, 0));
  await tester.pump();
  for (final point in waypoints) {
    await gesture.moveTo(point);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  group('the reported lane', () {
    testWidgets('is the bar own lane when the pointer stays on its row', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _dragThrough(tester, const Offset(300, _row0Y), const [Offset(340, _row0Y)]);

      expect(log.lanes, isNotEmpty);
      expect(log.lanes.last, 't1');
      expect(log.starts.last, closeTo(20, 1e-9));
    });

    testWidgets('is the lane under the pointer after a diagonal drag', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _dragThrough(tester, const Offset(300, _row0Y), const [Offset(340, _row1Y)]);

      expect(log.lanes.last, 't2');
      expect(log.starts.last, closeTo(20, 1e-9), reason: 're-laning does not retime');
    });

    testWidgets('crosses more than one lane at a time', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _dragThrough(tester, const Offset(300, _row0Y), const [Offset(320, _row2Y)]);

      expect(log.lanes.last, 't3');
    });

    testWidgets('follows the pointer back rather than the distance travelled', (tester) async {
      // The lane is read from where the pointer *is*, not from an accumulated
      // delta: a drag that wanders down and returns must land where it began,
      // or an overshoot would be unrecoverable without releasing.
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _dragThrough(tester, const Offset(300, _row0Y), const [
        Offset(320, _row2Y),
        Offset(340, _row0Y),
      ]);

      expect(log.lanes, containsAllInOrder(['t3', 't1']));
      expect(log.lanes.last, 't1');
    });
  });

  group('past the ends', () {
    testWidgets('a drag above the first row clamps to it', (tester) async {
      // Not the source lane and not nothing: the pointer is unambiguously
      // aimed upward, so the topmost lane is what it means.
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _dragThrough(tester, const Offset(300, _row1Y), const [Offset(340, 20)]);

      expect(log.lanes.last, 't1');
    });

    testWidgets('a drag below the last row clamps to it', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _dragThrough(tester, const Offset(300, _row0Y), const [Offset(340, 580)]);

      expect(log.lanes.last, 't3');
    });
  });

  group('what re-laning does not touch', () {
    testWidgets('trimming an edge never reports a lane', (tester) async {
      // An edge drag changes when the clip starts, never which lane it is on;
      // dragging vertically off a trim handle must not silently re-home it.
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _dragThrough(tester, const Offset(272, _row0Y), const [Offset(300, _row2Y)]);

      expect(log.lanes, isEmpty);
      expect(log.resized, isNotNull);
    });

    testWidgets('a bar still cannot be dragged before frame zero', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _dragThrough(tester, const Offset(300, _row0Y), const [Offset(100, _row1Y)]);

      expect(log.starts.last, 0);
      expect(log.lanes.last, 't2');
    });
  });

  group('the snap guide', () {
    testWidgets('is host state the widget only paints', (tester) async {
      // Like the playhead and the selection: the host decides where the snap
      // landed and the widget draws it, so one decider owns the rule.
      final log = _Log();
      await tester.pumpWidget(_harness(log, snapFrame: 60));
      await tester.pumpWidget(_harness(log, snapFrame: 90));
      await tester.pumpWidget(_harness(log));

      expect(tester.takeException(), isNull);
    });

    testWidgets('off the visible span paints nothing and throws nothing', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log, snapFrame: 100000));

      expect(tester.takeException(), isNull);
    });

    testWidgets('pulses when it catches, and settles', (tester) async {
      // The same brief flash the canvas guides use: a snap that arrives with
      // no announcement is easy to miss under a moving pointer.
      final log = _Log();
      await tester.pumpWidget(_harness(log));
      expect(tester.hasRunningAnimations, isFalse, reason: 'nothing caught anything yet');

      await tester.pumpWidget(_harness(log, snapFrame: 60));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isFalse, reason: 'the pulse is brief');
    });

    testWidgets('pulses again on a different frame but not on the same one', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log, snapFrame: 60));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.pumpWidget(_harness(log, snapFrame: 60));
      expect(tester.hasRunningAnimations, isFalse, reason: 'nothing new to announce');

      await tester.pumpWidget(_harness(log, snapFrame: 90));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('does not pulse when a drag lets go of a line', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log, snapFrame: 60));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.pumpWidget(_harness(log));

      expect(tester.hasRunningAnimations, isFalse, reason: 'losing a snap is not an event');
    });
  });
}
