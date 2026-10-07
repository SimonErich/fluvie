// Selecting bars on the timeline. Selection is host state, like every other
// highlight the widget draws: it reports the click and the rubber band, and
// paints exactly the set it is handed.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

// The harness centers a 620x220 timeline on the 800x600 test surface, so
// with the default label column (140), ruler (24), and zoom (4 px/frame):
// lanes start at global x 230, the ruler band is y 190..214, and track row
// N occupies y 214+28N..242+28N.
const double _row0Y = 228;
const double _row1Y = 256;
const double _row2Y = 284;

const _green = Color(0xFF2ECC8F);

/// Bar a runs 10..40 (px 270..390) on row 0, bar b runs 60..90 (px 470..590)
/// on row 1, and row 2 is empty.
List<TimelineTrack> _tracks() => const [
  TimelineTrack(
    id: 't1',
    label: 'Video 1',
    bars: [TimelineBar(id: 'a', start: 10, end: 40, color: _green)],
  ),
  TimelineTrack(
    id: 't2',
    label: 'Video 2',
    bars: [TimelineBar(id: 'b', start: 60, end: 90, color: _green)],
  ),
  TimelineTrack(id: 't3', label: 'Video 3'),
];

final class _Log {
  final List<({String id, bool additive})> taps = [];
  final List<({Set<String> ids, bool additive})> marquees = [];
}

Widget _harness(_Log log, {Set<String> selectedBarIds = const {}}) => OiThemeScope(
  data: OiThemeData.dark(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 620,
        height: 220,
        child: TrackTimeline(
          tracks: _tracks(),
          fps: 30,
          totalFrames: 300,
          playhead: 60,
          selection: TrackTimelineSelection(
            selectedBarIds: selectedBarIds,
          ),
          navigation: TrackTimelineNavigation(
            onBarTapped: (id, {required additive}) => log.taps.add((id: id, additive: additive)),
            onBarsMarqueed: (ids, {required additive}) =>
                log.marquees.add((ids: ids, additive: additive)),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _marquee(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveTo(Offset(from.dx + 4, from.dy));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  group('clicking a bar', () {
    testWidgets('reports it plainly', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await tester.tapAt(const Offset(300, _row0Y));
      await tester.pump();

      expect(log.taps.single, (id: 'a', additive: false));
    });

    testWidgets('with Shift held reports an additive click', (tester) async {
      // Shift adds a bar rather than selecting a range: on a surface with two
      // axes the honest range gesture is the rubber band, and one modifier
      // cannot mean both.
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(const Offset(300, _row0Y));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(log.taps.single, (id: 'a', additive: true));
    });

    testWidgets('with Ctrl held reports an additive click too', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tapAt(const Offset(300, _row0Y));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(log.taps.single.additive, isTrue);
    });
  });

  group('the rubber band', () {
    testWidgets('collects every bar it touches, across lanes', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _marquee(tester, const Offset(260, _row0Y - 10), const Offset(600, _row1Y + 10));

      expect(log.marquees.single.ids, {'a', 'b'});
      expect(log.marquees.single.additive, isFalse);
    });

    testWidgets('touching is enough; it need not swallow the bar', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      // Starting clear of the bar (its right edge and trim zone end at 395)
      // and sweeping back over its tail, across the top half of the row only.
      await _marquee(tester, const Offset(420, _row0Y - 12), const Offset(385, _row0Y));

      expect(log.marquees.single.ids, {'a'});
    });

    testWidgets('over empty space reports an empty set rather than nothing', (tester) async {
      // The host reads that as a clear. Reporting nothing at all would leave a
      // stale selection behind a gesture that plainly means "none of these".
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _marquee(tester, const Offset(260, _row2Y - 6), const Offset(600, _row2Y + 6));

      expect(log.marquees.single.ids, isEmpty);
    });

    testWidgets('extends the selection when Shift is held', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _marquee(tester, const Offset(460, _row1Y - 6), const Offset(600, _row1Y + 6));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(log.marquees.single.ids, {'b'});
      expect(log.marquees.single.additive, isTrue);
    });

    testWidgets('drags backwards just as well', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _marquee(tester, const Offset(600, _row1Y + 10), const Offset(260, _row0Y - 10));

      expect(log.marquees.single.ids, {'a', 'b'});
    });

    testWidgets('never starts on a bar, which is a move', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log));

      await _marquee(tester, const Offset(300, _row0Y), const Offset(600, _row1Y));

      expect(log.marquees, isEmpty, reason: 'a drag from a bar retimes it');
    });
  });

  group('painting the selection', () {
    testWidgets('takes the set it is given without deciding anything', (tester) async {
      final log = _Log();
      await tester.pumpWidget(_harness(log, selectedBarIds: const {'a'}));
      await tester.pumpWidget(_harness(log, selectedBarIds: const {'a', 'b'}));
      await tester.pumpWidget(_harness(log));

      expect(tester.takeException(), isNull);
      expect(log.taps, isEmpty, reason: 'painting a selection is not reporting one');
    });
  });
}
