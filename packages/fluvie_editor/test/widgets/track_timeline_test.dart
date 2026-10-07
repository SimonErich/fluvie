import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiIcons, OiThemeData, OiThemeScope;

// The harness centers a 620x220 timeline on the 800x600 test surface, so
// with the default label column (140), ruler (24), and zoom (4 px/frame):
// lanes start at global x 230, the ruler band is y 190..214, and track row
// N occupies y 214+28N..242+28N. Bar b1 (frames 10..40) paints at x 270..390.
const double _row0Y = 228;
const double _row1Y = 256;
const double _rulerY = 200;

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
        easing: Curves.easeInOut,
        badge: 'fadeIn',
      ),
    ],
  ),
  TimelineTrack(id: 't2', label: 'Body'),
];

List<TimelineTrack> _grouped() => const [
  TimelineTrack(id: 'g', label: 'Group', isGroup: true),
  TimelineTrack(id: 'c1', label: 'Child', depth: 1),
  TimelineTrack(id: 't', label: 'Tail'),
];

final class _Log {
  final List<String> events = [];
  final List<double> scrubs = [];
  double? movedStart;
  (double, double)? resized;
  String? tappedBar;
  (String, double)? tappedTrack;
  String? tappedLabel;
}

Widget _harness(
  _Log log, {
  List<TimelineTrack>? tracks,
  TrackTimelineController? controller,
  double totalFrames = 300,
  Widget? emptyAction,
  Set<String> selectedTrackIds = const {},
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
          totalFrames: totalFrames,
          playhead: 60,
          controller: controller,
          selection: TrackTimelineSelection(
            selectedTrackIds: selectedTrackIds,
          ),
          appearance: TrackTimelineAppearance(
            emptyMessage: 'No animations yet.',
            emptyAction: emptyAction,
          ),
          navigation: TrackTimelineNavigation(
            onScrub: log.scrubs.add,
            onLabelTapped: (id) => log.tappedLabel = id,
            onBarTapped: (id, {required additive}) => log.tappedBar = id,
            onTrackTapped: (id, frame) => log.tappedTrack = (id, frame),
          ),
          edit: TrackTimelineEditActions(
            onDragStarted: (id) => log.events.add('start:$id'),
            onDragEnded: (id) => log.events.add('end:$id'),
            onBarMoved: (id, newStart, lane) {
              log.events.add('move:$id');
              log.movedStart = newStart;
            },
            onBarResized: (id, newStart, newEnd) {
              log.events.add('resize:$id');
              log.resized = (newStart, newEnd);
            },
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
  testWidgets('dragging a bar body retimes it and brackets the drag', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(300, _row0Y), const Offset(40, 0));
    expect(log.events.first, 'start:b1');
    expect(log.events.last, 'end:b1');
    expect(log.events.where((e) => e == 'move:b1'), isNotEmpty);
    expect(log.movedStart, closeTo(20, 1e-9));
  });

  testWidgets('a bar never drags before frame zero', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(300, _row0Y), const Offset(-200, 0));
    expect(log.movedStart, 0);
  });

  testWidgets('dragging the right edge changes the duration only', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(389, _row0Y), const Offset(-20, 0));
    expect(log.resized, isNotNull);
    expect(log.resized!.$1, 10);
    expect(log.resized!.$2, closeTo(35, 1e-9));
    expect(log.events.where((e) => e.startsWith('move:')), isEmpty);
  });

  testWidgets('a bar keeps at least one frame when trimmed hard', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(389, _row0Y), const Offset(-200, 0));
    expect(log.resized!.$2, 11);
  });

  testWidgets('dragging the left edge moves the start and keeps the end', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(271, _row0Y), const Offset(8, 0));
    expect(log.resized!.$1, closeTo(12, 1e-9));
    expect(log.resized!.$2, 40);
  });

  testWidgets('tapping a bar reports it', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(300, _row0Y));
    await tester.pump();
    expect(log.tappedBar, 'b1');
  });

  testWidgets('tapping empty lane space reports the track and frame', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(430, _row1Y));
    await tester.pump();
    expect(log.tappedTrack!.$1, 't2');
    expect(log.tappedTrack!.$2, closeTo(50, 1e-9));
  });

  testWidgets('a drag from empty lane space moves nothing', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(430, _row1Y), const Offset(40, 0));
    expect(log.events, isEmpty);
    expect(log.movedStart, isNull);
    expect(log.resized, isNull);
  });

  testWidgets('tapping the ruler jumps the playhead', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tapAt(const Offset(310, _rulerY));
    await tester.pump();
    expect(log.scrubs.single, closeTo(20, 1e-9));
  });

  testWidgets('shift+wheel scrolls the tracks vertically', (tester) async {
    final log = _Log();
    final tall = [
      for (var i = 0; i < 8; i++) TimelineTrack(id: 'r$i', label: 'Row $i'),
    ];
    await tester.pumpWidget(_harness(log, tracks: tall));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(const Offset(430, _row0Y));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 28)));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    // One row scrolled away: the point that was row 0 now reads row 1.
    await tester.tapAt(const Offset(430, _row0Y));
    await tester.pump();
    expect(log.tappedTrack!.$1, 'r1');
  });

  testWidgets('scrubbing the ruler reports frames and clamps at zero', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await _drag(tester, const Offset(270, _rulerY), const Offset(40, 0));
    expect(log.scrubs.first, closeTo(10, 1e-9));
    expect(log.scrubs.last, closeTo(20, 1e-9));
    await _drag(tester, const Offset(270, _rulerY), const Offset(-200, 0));
    expect(log.scrubs.last, 0);
  });

  testWidgets('collapsing a group hides its children', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, tracks: _grouped()));
    expect(find.text('Child'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-collapse-g')));
    await tester.pump();
    expect(find.text('Child'), findsNothing);
    expect(find.text('Tail'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-collapse-g')));
    await tester.pump();
    expect(find.text('Child'), findsOneWidget);
  });

  testWidgets('a wheel over the lanes pans the timeline horizontally', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(const Offset(430, _row1Y));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
    await tester.pump();
    await tester.tapAt(const Offset(430, _row1Y));
    await tester.pump();
    expect(log.tappedTrack!.$2, closeTo(60, 1e-9));
  });

  testWidgets('ctrl+wheel zooms around the cursor', (tester) async {
    final log = _Log();
    final controller = TrackTimelineController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_harness(log, controller: controller));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(const Offset(430, _row1Y));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(controller.pixelsPerFrame, greaterThan(4));
  });

  testWidgets('the empty timeline explains itself and offers the action slot', (tester) async {
    final log = _Log();
    await tester.pumpWidget(
      _harness(
        log,
        tracks: const [],
        emptyAction: const Text('Add one', key: ValueKey('act')),
      ),
    );
    expect(find.text('No animations yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('act')), findsOneWidget);
    expect(find.byIcon(OiIcons.chevronDown), findsNothing);
  });

  testWidgets('the group chevron flips with collapse state', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, tracks: _grouped()));
    expect(find.byIcon(OiIcons.chevronDown), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-collapse-g')));
    await tester.pump();
    expect(find.byIcon(OiIcons.chevronRight), findsOneWidget);
  });

  testWidgets('tapping a track label reports it, without scrubbing', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log));
    await tester.tap(find.text('Body'));
    await tester.pump();
    expect(log.tappedLabel, 't2');
    // The label tap owns selection; it never scrubs or taps the lane.
    expect(log.tappedTrack, isNull);
    expect(log.scrubs, isEmpty);
  });

  testWidgets('the collapse chevron still toggles, not selects the label', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, tracks: _grouped()));
    await tester.tap(find.byKey(const ValueKey('timeline-collapse-g')));
    await tester.pump();
    expect(find.text('Child'), findsNothing);
    expect(log.tappedLabel, isNull);
  });

  testWidgets('a selected track survives a rebuild with new selection', (tester) async {
    final log = _Log();
    await tester.pumpWidget(_harness(log, selectedTrackIds: const {'t1'}));
    await tester.pump();
    // The highlight is painted; the golden pins the pixels. Here we only
    // confirm the selected id threads through without disturbing labels.
    expect(find.text('Title'), findsOneWidget);
    await tester.pumpWidget(_harness(log, selectedTrackIds: const {'t2'}));
    await tester.pump();
    expect(find.text('Body'), findsOneWidget);
  });
}
