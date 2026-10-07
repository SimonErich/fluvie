import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

// The harness centers a 620x220 timeline on the 800x600 test surface, so
// with the default label column (140), ruler (24), and zoom (4 px/frame):
// lanes start at global x 230 (frame 0) and the ruler band is y 190..214.
const double _rulerY = 200;
const double _laneY = 228;

const _green = Color(0xFF2ECC8F);

List<TimelineTrack> _tracks() => const [
  TimelineTrack(
    id: 't1',
    label: 'Title',
    bars: [
      TimelineBar(id: 'b1', start: 10, end: 40, color: _green, badge: 'fadeIn'),
    ],
  ),
];

final class _Log {
  final List<(double, double)> ranges = [];
  final List<double> scrubs = [];
  int cleared = 0;
}

Widget _harness(_Log log, {({double start, double end})? rangeSelection}) => OiThemeScope(
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
          totalFrames: 100,
          playhead: 60,
          selection: TrackTimelineSelection(
            rangeSelection: rangeSelection,
          ),
          navigation: TrackTimelineNavigation(
            onScrub: log.scrubs.add,
            onRangeSelected: (start, end) => log.ranges.add((start, end)),
            onRangeCleared: () => log.cleared++,
          ),
        ),
      ),
    ),
  ),
);

Future<void> _shiftDrag(WidgetTester tester, Offset from, Offset by) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.up();
  await tester.pump();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

void main() {
  testWidgets('a shift-drag on the ruler selects a range, not a scrub', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _shiftDrag(tester, const Offset(270, _rulerY), const Offset(80, 0));
    expect(log.ranges, isNotEmpty);
    expect(log.ranges.last, (10.0, 30.0));
    expect(log.scrubs, isEmpty);
  });

  testWidgets('a right-to-left shift-drag normalizes to a forward range', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _shiftDrag(tester, const Offset(350, _rulerY), const Offset(-80, 0));
    expect(log.ranges.last, (10.0, 30.0));
  });

  testWidgets('the range clamps to the timeline', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    // Frame 0 sits at x 230 and frame 100 at x 630; drag across both ends.
    await _shiftDrag(tester, const Offset(232, _rulerY), const Offset(500, 0));
    final (start, end) = log.ranges.last;
    expect(start, 0.5);
    expect(end, 100.0);
  });

  testWidgets('a plain ruler drag still scrubs', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    final gesture = await tester.startGesture(
      const Offset(270, _rulerY),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(log.scrubs, isNotEmpty);
    expect(log.ranges, isEmpty);
  });

  testWidgets('a motionless shift-press selects nothing', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _shiftDrag(tester, const Offset(270, _rulerY), Offset.zero);
    expect(log.ranges, isEmpty);
    expect(log.cleared, 0);
  });

  testWidgets('Escape clears the selected range from the lanes', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, rangeSelection: (start: 10, end: 30)));
    // A lane tap focuses the lanes, the same surface Delete listens on.
    await tester.tapAt(const Offset(500, _laneY));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(log.cleared, 1);
  });

  testWidgets('a range drag itself arms Escape by focusing the lanes', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, rangeSelection: (start: 10, end: 30)));
    await _shiftDrag(tester, const Offset(270, _rulerY), const Offset(80, 0));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(log.cleared, 1);
  });

  testWidgets('Escape without a range stays untouched', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(500, _laneY));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(log.cleared, 0);
  });

  testWidgets('the selected range paints without disturbing the lanes', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, rangeSelection: (start: 10, end: 30)));
    expect(find.byType(TrackTimeline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
