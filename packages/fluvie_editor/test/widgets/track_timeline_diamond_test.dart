import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

// Same geometry as track_timeline_test.dart: a 620x220 timeline centered on
// the 800x600 surface, labels 140, ruler 24, default zoom 4 px/frame — the
// lanes start at global x 230, row 0 centers on y 228. Bar b1 covers frames
// 10..40 (x 270..390); its diamonds sit at frames 10, 25, and 40.
const double _row0Y = 228;

const _green = Color(0xFF2ECC8F);

List<TimelineTrack> _tracks() => const [
  TimelineTrack(
    id: 't1',
    label: 'Title',
    bars: [
      TimelineBar(
        id: 'b1',
        start: 10,
        end: 40,
        color: _green,
        diamonds: [
          TimelineDiamond(id: 'k0', frame: 10),
          TimelineDiamond(id: 'k1', frame: 25),
          TimelineDiamond(id: 'k2', frame: 40),
        ],
      ),
    ],
  ),
  TimelineTrack(id: 't2', label: 'Body'),
];

final class _Log {
  final List<String> events = [];
  (String, String)? tapped;
  (String, String, double)? moved;
  (String, String)? deleted;
  String? tappedBar;
  (String, double)? tappedTrack;
}

Widget _harness(_Log log, {String? selectedDiamondId}) => OiThemeScope(
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
            selectedDiamondId: selectedDiamondId,
          ),
          edit: TrackTimelineEditActions(
            onDragStarted: (id) => log.events.add('start:$id'),
            onDragEnded: (id) => log.events.add('end:$id'),
            onBarMoved: (id, newStart, lane) => log.events.add('move:$id'),
            onBarResized: (id, newStart, newEnd) => log.events.add('resize:$id'),
          ),
          navigation: TrackTimelineNavigation(
            onBarTapped: (id, {required additive}) => log.tappedBar = id,
            onTrackTapped: (id, frame) => log.tappedTrack = (id, frame),
          ),
          overlays: TrackTimelineOverlayActions(
            onDiamondTapped: (barId, diamondId) => log.tapped = (barId, diamondId),
            onDiamondMoved: (barId, diamondId, frame) {
              log.events.add('diamond:$diamondId');
              log.moved = (barId, diamondId, frame);
            },
            onDiamondDeleted: (barId, diamondId) => log.deleted = (barId, diamondId),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _drag(WidgetTester tester, Offset from, Offset by) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('tapping a diamond reports it instead of the bar', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(330, _row0Y));
    await tester.pump();
    expect(log.tapped, ('b1', 'k1'));
    expect(log.tappedBar, isNull);
    expect(log.tappedTrack, isNull);
  });

  testWidgets('tapping the bar body away from diamonds still reports the bar', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(300, _row0Y));
    await tester.pump();
    expect(log.tappedBar, 'b1');
    expect(log.tapped, isNull);
  });

  testWidgets('dragging a diamond moves it and brackets the drag', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(330, _row0Y), const Offset(40, 0));
    expect(log.events.first, 'start:k1');
    expect(log.events.last, 'end:k1');
    expect(log.moved!.$1, 'b1');
    expect(log.moved!.$2, 'k1');
    expect(log.moved!.$3, closeTo(35, 1e-9));
    expect(log.events.where((e) => e.startsWith('move:')), isEmpty);
  });

  testWidgets('a diamond never leaves its bar', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(330, _row0Y), const Offset(400, 0));
    expect(log.moved!.$3, 40);
    await _drag(tester, const Offset(330, _row0Y), const Offset(-400, 0));
    expect(log.moved!.$3, 10);
  });

  testWidgets('a diamond on the bar edge wins over the edge grab', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(390, _row0Y), const Offset(-40, 0));
    expect(log.moved!.$2, 'k2');
    expect(log.moved!.$3, closeTo(30, 1e-9));
    expect(log.events.where((e) => e.startsWith('resize:')), isEmpty);
  });

  testWidgets('Delete removes the selected diamond after a tap focused the lanes', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, selectedDiamondId: 'k1'));
    await tester.tapAt(const Offset(330, _row0Y));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(log.deleted, ('b1', 'k1'));
  });

  testWidgets('Backspace deletes too; without a selection the key is ignored', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, selectedDiamondId: 'k0'));
    await tester.tapAt(const Offset(270, _row0Y));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(log.deleted, ('b1', 'k0'));

    final quiet = _Log();
    await tester.pumpWidget(_harness(quiet));
    await tester.tapAt(const Offset(330, _row0Y));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(quiet.deleted, isNull);
  });

  testWidgets('diamonds are values', (tester) async {
    const diamond = TimelineDiamond(id: 'k', frame: 5);
    expect(diamond, const TimelineDiamond(id: 'k', frame: 5));
    expect(diamond.hashCode, const TimelineDiamond(id: 'k', frame: 5).hashCode);
    expect(diamond, isNot(const TimelineDiamond(id: 'k', frame: 6)));
    expect('$diamond', contains('k'));
    // Bars compare their diamond lists by value too.
    const bar = TimelineBar(id: 'b', start: 0, end: 10, color: _green, diamonds: [diamond]);
    expect(
      bar,
      const TimelineBar(
        id: 'b',
        start: 0,
        end: 10,
        color: _green,
        diamonds: [TimelineDiamond(id: 'k', frame: 5)],
      ),
    );
    expect(bar, isNot(const TimelineBar(id: 'b', start: 0, end: 10, color: _green)));
  });
}
