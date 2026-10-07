import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

// Same geometry as track_timeline_test.dart: a 620x220 timeline centered on
// the 800x600 surface, labels 140, ruler 24, default zoom 4 px/frame — the
// lanes start at global x 230 / y 214, rows center on y 228 and 256. Bar b1
// covers frames 10..40 (x 270..390), bar b2 frames 50..80 (x 430..550); the
// link runs from b1's end edge down and into b2's start edge.
const double _row0Y = 228;
const double _row1Y = 256;

const _green = Color(0xFF2ECC8F);
const _blue = Color(0xFF3B82F6);

List<TimelineTrack> _tracks() => const [
  TimelineTrack(
    id: 't1',
    label: 'Title',
    bars: [TimelineBar(id: 'b1', start: 10, end: 40, color: _green)],
  ),
  TimelineTrack(
    id: 't2',
    label: 'Body',
    bars: [TimelineBar(id: 'b2', start: 50, end: 80, color: _green)],
  ),
];

final class _Log {
  final List<String> events = [];
  (String, String)? dropped;
  String? tappedLink;
  String? deletedLink;
  String? tappedBar;
  (String, double)? tappedTrack;
}

Widget _harness(_Log log, {String? selectedLinkId}) => OiThemeScope(
  data: OiThemeData.dark(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 620,
        height: 220,
        child: TrackTimeline(
          tracks: _tracks(),
          links: const [
            TimelineLink(
              id: 'l1',
              fromBarId: 'b2',
              toBarId: 'b1',
              toEdge: TimelineLinkEdge.end,
              color: _blue,
              label: 'ends',
            ),
          ],
          fps: 30,
          totalFrames: 300,
          selection: TrackTimelineSelection(
            selectedLinkId: selectedLinkId,
          ),
          edit: TrackTimelineEditActions(
            onBarMoved: (id, newStart, lane) => log.events.add('move:$id'),
            onBarResized: (id, newStart, newEnd) => log.events.add('resize:$id'),
          ),
          navigation: TrackTimelineNavigation(
            onBarTapped: (id, {required additive}) => log.tappedBar = id,
            onTrackTapped: (id, frame) => log.tappedTrack = (id, frame),
          ),
          overlays: TrackTimelineOverlayActions(
            onLinkDropped: (fromBarId, toBarId) => log.dropped = (fromBarId, toBarId),
            onLinkTapped: (id) => log.tappedLink = id,
            onLinkDeleted: (id) => log.deletedLink = id,
          ),
        ),
      ),
    ),
  ),
);

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  final by = to - from;
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.moveBy(Offset(by.dx / 2, by.dy / 2));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('tapping the elbow connector reports the link', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    // The vertical run sits on b1's end x (390) between the two rows.
    await tester.tapAt(const Offset(390, 245));
    await tester.pump();
    expect(log.tappedLink, 'l1');
    expect(log.tappedBar, isNull);
    expect(log.tappedTrack, isNull);
  });

  testWidgets('the horizontal run into the source bar is tappable too', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(410, _row1Y));
    await tester.pump();
    expect(log.tappedLink, 'l1');
  });

  testWidgets('inside a trim zone the bar edge still wins over the link', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    // (390, row0) is on the connector but strictly inside b1's end trim zone.
    await tester.tapAt(const Offset(388, _row0Y));
    await tester.pump();
    expect(log.tappedBar, 'b1');
    expect(log.tappedLink, isNull);
  });

  testWidgets('dragging from the link handle onto another bar drops a link', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    // b2's handle sits at its top-center: x = 65 * 4 + 230 = 490, y = row 1
    // top (242) + 4.
    await _drag(tester, const Offset(490, 246), const Offset(330, _row0Y));
    expect(log.dropped, ('b2', 'b1'));
    expect(log.events.where((e) => e.startsWith('move:')), isEmpty);
  });

  testWidgets('releasing a link drag over empty space drops nothing', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(490, 246), const Offset(600, _row0Y));
    expect(log.dropped, isNull);
  });

  testWidgets('a drag on the bar body below the handle still moves the bar', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(490, _row1Y), const Offset(530, _row1Y));
    expect(log.events.where((e) => e.startsWith('move:b2')), isNotEmpty);
    expect(log.dropped, isNull);
  });

  testWidgets('Delete removes the selected link once the lanes hold focus', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, selectedLinkId: 'l1'));
    await tester.tapAt(const Offset(600, _row0Y));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(log.deletedLink, 'l1');
  });

  testWidgets('hovering a bar shows its handle without breaking gestures', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(490, _row1Y));
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(const Offset(330, _row0Y));
    await tester.pump();
    await gesture.moveTo(const Offset(50, 50));
    await tester.pump();
    // Hover is a paint affordance only; interactions stay unchanged.
    expect(log.tappedBar, isNull);
  });

  testWidgets('links and violations are values', (tester) async {
    const link = TimelineLink(
      id: 'l',
      fromBarId: 'a',
      toBarId: 'b',
      toEdge: TimelineLinkEdge.start,
      color: _blue,
    );
    expect(
      link,
      const TimelineLink(
        id: 'l',
        fromBarId: 'a',
        toBarId: 'b',
        toEdge: TimelineLinkEdge.start,
        color: _blue,
      ),
    );
    expect(
      link,
      isNot(
        const TimelineLink(
          id: 'l',
          fromBarId: 'a',
          toBarId: 'b',
          toEdge: TimelineLinkEdge.end,
          color: _blue,
        ),
      ),
    );
    expect(link.hashCode, isNot(0));
    expect('$link', contains('l'));
    const bar = TimelineBar(id: 'b', start: 0, end: 10, color: _green, violation: true);
    expect(bar, isNot(const TimelineBar(id: 'b', start: 0, end: 10, color: _green)));
    expect(bar.violation, isTrue);
  });
}
