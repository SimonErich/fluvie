import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

// Same geometry as track_timeline_test.dart: a 620x220 timeline centered on
// the 800x600 surface, labels 140, ruler 24, default zoom 4 px/frame — the
// ruler band spans global y 190..214 with the lanes at x >= 230. Marker m0
// sits on frame 20 (x 310), m1 on frame 60 (x 470).
const double _rulerY = 202;
const double _row0Y = 228;

const _green = Color(0xFF2ECC8F);

final class _Log {
  final List<String> events = [];
  final List<double> scrubs = [];
  (String, double)? moved;
  double? inserted;
  String? removed;
  String? tappedMarker;
}

Widget _harness(_Log log, {String? selectedMarkerId}) => OiThemeScope(
  data: OiThemeData.dark(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 620,
        height: 220,
        child: TrackTimeline(
          tracks: const [
            TimelineTrack(
              id: 't1',
              label: 'Title',
              bars: [TimelineBar(id: 'b1', start: 10, end: 40, color: _green)],
            ),
          ],
          markers: const [
            TimelineMarker(id: 'm0', frame: 20, label: '2'),
            TimelineMarker(id: 'm1', frame: 60, label: '3'),
          ],
          fps: 30,
          totalFrames: 300,
          selection: TrackTimelineSelection(
            selectedMarkerId: selectedMarkerId,
          ),
          navigation: TrackTimelineNavigation(
            onScrub: log.scrubs.add,
          ),
          edit: TrackTimelineEditActions(
            onDragStarted: (id) => log.events.add('start:$id'),
            onDragEnded: (id) => log.events.add('end:$id'),
          ),
          overlays: TrackTimelineOverlayActions(
            onMarkerMoved: (id, frame) => log.moved = (id, frame),
            onMarkerInserted: (frame) => log.inserted = frame,
            onMarkerRemoved: (id) => log.removed = id,
            onMarkerTapped: (id) => log.tappedMarker = id,
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
  testWidgets('tapping the ruler away from markers still scrubs', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(350, _rulerY));
    await tester.pump();
    expect(log.scrubs, [30]);
    expect(log.tappedMarker, isNull);
  });

  testWidgets('tapping a marker selects it instead of scrubbing', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(312, _rulerY));
    await tester.pump();
    expect(log.tappedMarker, 'm0');
    expect(log.scrubs, isEmpty);
  });

  testWidgets('dragging a marker reports its new frame and brackets the drag', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(310, _rulerY), const Offset(40, 0));
    expect(log.events.first, 'start:m0');
    expect(log.events.last, 'end:m0');
    expect(log.moved, ('m0', 30));
    expect(log.scrubs, isEmpty);
    expect(log.removed, isNull);
  });

  testWidgets('dragging a marker off the ruler removes it on release', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(310, _rulerY), const Offset(0, 60));
    expect(log.removed, 'm0');
    expect(log.events.first, 'start:m0');
    expect(log.events.last, 'end:m0');
  });

  testWidgets('a double tap on empty ruler space inserts a marker there', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(350, _rulerY));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(350, _rulerY));
    await tester.pump();
    expect(log.inserted, 30);
    // Only the first tap scrubbed.
    expect(log.scrubs, [30]);
  });

  testWidgets('two quick taps far apart never insert', (tester) async {
    // The manual double-tap check requires the taps within 6 px; the 350 ms
    // window rides real time (the house DateTime pattern), so the negative
    // case pins the position guard.
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(350, _rulerY));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(450, _rulerY));
    await tester.pump();
    expect(log.inserted, isNull);
    expect(log.scrubs, [30, 55]);
  });

  testWidgets('Delete removes the selected marker once the lanes hold focus', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, selectedMarkerId: 'm1'));
    await tester.tapAt(const Offset(600, _row0Y));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(log.removed, 'm1');
  });

  testWidgets('a ruler drag away from markers keeps scrubbing', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(350, _rulerY), const Offset(20, 0));
    expect(log.scrubs, isNotEmpty);
    expect(log.moved, isNull);
  });

  testWidgets('markers are values', (tester) async {
    const marker = TimelineMarker(id: 'm', frame: 12, label: '2');
    expect(marker, const TimelineMarker(id: 'm', frame: 12, label: '2'));
    expect(marker.hashCode, const TimelineMarker(id: 'm', frame: 12, label: '2').hashCode);
    expect(marker, isNot(const TimelineMarker(id: 'm', frame: 13, label: '2')));
    expect('$marker', contains('m'));
  });
}
