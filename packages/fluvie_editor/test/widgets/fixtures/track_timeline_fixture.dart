import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

const timelineSize = Size(760, 200);
const ValueKey<String> frameKey = ValueKey('track-public-frame');
const ValueKey<String> timelineKey = ValueKey('track-public-state');
const fixtureTracks = [
  TimelineTrack(
    id: 'first',
    label: 'First',
    bars: [
      TimelineBar(
        id: 'bar-a',
        start: 0,
        end: 50,
        color: Color(0xff4488cc),
        diamonds: [TimelineDiamond(id: 'diamond-a', frame: 20)],
      ),
    ],
  ),
  TimelineTrack(
    id: 'second',
    label: 'Second',
    bars: [TimelineBar(id: 'bar-b', start: 60, end: 90, color: Color(0xffcc8844))],
  ),
];
const fixtureLinks = [
  TimelineLink(
    id: 'link-a',
    fromBarId: 'bar-a',
    toBarId: 'bar-b',
    toEdge: TimelineLinkEdge.start,
    color: Color(0xffaa55aa),
  ),
];

final class TimelineFixture {
  final ValueNotifier<int> refresh = ValueNotifier(0);
  final firstController = TrackTimelineController();
  final secondController = TrackTimelineController(pixelsPerFrame: 6);
  final events = <String>[];
  TrackTimelineController? replacementController;
  String generation = 'A';
  bool acceptsDrop = false;
  bool dark = true;
  double totalFrames = 100;
  double playhead = 5;
  double? snapFrame;
  Set<String> selectedTrackIds = const {};
  Set<String> selectedBarIds = const {};
  String? selectedDiamondId;
  String? selectedLinkId;
  ({double start, double end})? range;
  List<TimelineLink> links = const [];
  List<TimelineMarker> markers = const [];
  List<TimelineTrack> tracks = fixtureTracks;

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 300);
    await tester.binding.setSurfaceSize(const Size(900, 300));
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: refresh,
        builder: (context, _) {
          final tag = generation;
          return OiApp(
            theme: dark ? OiThemeData.dark() : OiThemeData.light(),
            home: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: frameKey,
                child: SizedBox(
                  width: timelineSize.width,
                  height: timelineSize.height,
                  child: TrackTimeline(
                    key: timelineKey,
                    tracks: tracks,
                    fps: 30,
                    totalFrames: totalFrames,
                    controller: replacementController ?? firstController,
                    playhead: playhead,
                    snapFrame: snapFrame,
                    links: links,
                    markers: markers,
                    selection: TrackTimelineSelection(
                      selectedTrackIds: selectedTrackIds,
                      selectedBarIds: selectedBarIds,
                      selectedDiamondId: selectedDiamondId,
                      selectedLinkId: selectedLinkId,
                      rangeSelection: range,
                    ),
                    navigation: TrackTimelineNavigation(
                      onRangeCleared: () => events.add('$tag:clear'),
                      onBarTapped: (bar, {required additive}) =>
                          events.add('$tag:tap:$bar:$additive'),
                    ),
                    overlays: TrackTimelineOverlayActions(
                      onDiamondDeleted: (bar, diamond) => events.add('$tag:delete:$bar:$diamond'),
                    ),
                    edit: TrackTimelineEditActions(
                      onDragStarted: (bar) => events.add('$tag:start:$bar'),
                      onBarMoved: (bar, start, track) => events.add('$tag:move:$bar:$start:$track'),
                      onDragEnded: (bar) => events.add('$tag:end:$bar'),
                      onForeignLaneDrop: acceptsDrop
                          ? (data, track, bar, frame) =>
                                events.add('$tag:drop:$data:$track:$bar:$frame')
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> update(WidgetTester tester) async {
    refresh.value++;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // The final controller's exact listener-detach lifecycle is deliberately observed.
    // ignore: invalid_use_of_protected_member
    expect(firstController.hasListeners, isFalse);
    // The final controller's exact listener-detach lifecycle is deliberately observed.
    // ignore: invalid_use_of_protected_member
    expect(secondController.hasListeners, isFalse);
    refresh.dispose();
    firstController.dispose();
    secondController.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  }
}

Finder laneTarget() =>
    find.descendant(of: find.byKey(timelineKey), matching: find.byType(DragTarget<Object>));

CustomPaint paintFromPublicBuilder(Widget root) {
  var current = root;
  while (current is! CustomPaint) {
    current = switch (current) {
      Focus(:final child) => child,
      MouseRegion(:final child?) => child,
      GestureDetector(:final child?) => child,
      ClipRect(:final child?) => child,
      _ => throw TestFailure('Unexpected original public SDK input tree: ${current.runtimeType}'),
    };
  }
  return current;
}

Future<Uint8List> paintBytes(WidgetTester tester, CustomPainter painter, Size size) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.ceil(), size.height.ceil());
    try {
      // The full native RGBA capture format is an explicit fixture contract.
      // ignore: avoid_redundant_argument_values
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } finally {
      image.dispose();
      picture.dispose();
    }
  });
  return bytes!;
}
