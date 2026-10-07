import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

typedef TimelineConstructor =
    TrackTimeline Function({
      required List<TimelineTrack> tracks,
      required double fps,
      required double totalFrames,
      double playhead,
      TrackTimelineController? controller,
      List<TimelineLink> links,
      List<TimelineMarker> markers,
      double? snapFrame,
      void Function(int fromFrame, int toFrame)? onFilmstripNeeded,
      TrackTimelineSelection selection,
      TrackTimelineNavigation navigation,
      TrackTimelineEditActions edit,
      TrackTimelineOverlayActions overlays,
      TrackTimelineLaneActions lanes,
      TrackTimelineAppearance appearance,
      Key? key,
    });

const newConstWidget = TrackTimeline(
  tracks: [],
  fps: 30,
  totalFrames: 100,
  // Explicit default-group inputs exercise the const constructor contract.
  // ignore: avoid_redundant_argument_values
  selection: TrackTimelineSelection(),
  // Explicit default-group inputs exercise the const constructor contract.
  // ignore: avoid_redundant_argument_values
  navigation: TrackTimelineNavigation(),
  // Explicit default-group inputs exercise the const constructor contract.
  // ignore: avoid_redundant_argument_values
  edit: TrackTimelineEditActions(),
  // Explicit default-group inputs exercise the const constructor contract.
  // ignore: avoid_redundant_argument_values
  overlays: TrackTimelineOverlayActions(),
  // Explicit default-group inputs exercise the const constructor contract.
  // ignore: avoid_redundant_argument_values
  lanes: TrackTimelineLaneActions(),
  // Explicit default-group inputs exercise the const constructor contract.
  // ignore: avoid_redundant_argument_values
  appearance: TrackTimelineAppearance(),
);

void barTapped(String id, {required bool additive}) {}
void barsMarqueed(Set<String> ids, {required bool additive}) {}
void barMoved(String id, double start, String target) {}
void foreignLaneDrop(Object data, String track, String? bar, double frame) {}

void main() {
  test('new public configurations retain const defaults and exact callable types', () {
    // The explicit callable type is the public compile-time contract under test.
    // ignore: omit_local_variable_types
    const TimelineConstructor construct = TrackTimeline.new;
    final value = construct(tracks: const [], fps: 30, totalFrames: 100);
    expect(
      [
        value.tracks,
        value.fps,
        value.totalFrames,
        value.playhead,
        value.controller,
        value.links,
        value.markers,
        value.snapFrame,
        value.onFilmstripNeeded,
        value.selection.selectedDiamondId,
        value.selection.selectedLinkId,
        value.selection.selectedMarkerId,
        value.selection.selectedTrackIds,
        value.selection.selectedBarIds,
        value.selection.rangeSelection,
        value.navigation.onScrub,
        value.navigation.onLabelTapped,
        value.navigation.onRangeSelected,
        value.navigation.onRangeCleared,
        value.navigation.onBarTapped,
        value.navigation.onBarsMarqueed,
        value.navigation.onTrackTapped,
        value.edit.onBarMoved,
        value.edit.onBarResized,
        value.edit.onEasingTapped,
        value.edit.onForeignDrop,
        value.edit.onForeignLaneDrop,
        value.edit.onDragStarted,
        value.edit.onDragEnded,
        value.overlays.onDiamondTapped,
        value.overlays.onDiamondMoved,
        value.overlays.onDiamondDeleted,
        value.overlays.onLinkDropped,
        value.overlays.onLinkTapped,
        value.overlays.onLinkDeleted,
        value.overlays.onMarkerMoved,
        value.overlays.onMarkerInserted,
        value.overlays.onMarkerRemoved,
        value.overlays.onMarkerTapped,
        value.lanes.onLaneReordered,
        value.lanes.onLaneLockToggled,
        value.lanes.onLaneMuteToggled,
        value.lanes.onLaneSoloToggled,
        value.appearance.emptyMessage,
        value.appearance.emptyAction,
        value.appearance.labelWidth,
        value.appearance.trackHeight,
        value.appearance.rulerHeight,
      ],
      [
        <TimelineTrack>[],
        30,
        100,
        0,
        null,
        <TimelineLink>[],
        <TimelineMarker>[],
        null,
        null,
        null,
        null,
        null,
        <String>{},
        <String>{},
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        'Nothing here yet.',
        null,
        140,
        28,
        24,
      ],
    );
    expect(newConstWidget.selection, same(const TrackTimelineSelection()));
    expect(newConstWidget.navigation, same(const TrackTimelineNavigation()));
    expect(newConstWidget.edit, same(const TrackTimelineEditActions()));
    expect(newConstWidget.overlays, same(const TrackTimelineOverlayActions()));
    expect(newConstWidget.lanes, same(const TrackTimelineLaneActions()));
    expect(newConstWidget.appearance, same(const TrackTimelineAppearance()));

    const navigation = TrackTimelineNavigation(
      onBarTapped: barTapped,
      onBarsMarqueed: barsMarqueed,
    );
    const edit = TrackTimelineEditActions(onBarMoved: barMoved, onForeignLaneDrop: foreignLaneDrop);
    // The explicit callable type is the public compile-time contract under test.
    // ignore: omit_local_variable_types
    final void Function(String, {required bool additive}) tapped = navigation.onBarTapped!;
    // The explicit callable type is the public compile-time contract under test.
    // ignore: omit_local_variable_types
    final void Function(Set<String>, {required bool additive}) marquee = navigation.onBarsMarqueed!;
    // The explicit callable type is the public compile-time contract under test.
    // ignore: omit_local_variable_types
    final void Function(String, double, String) move = edit.onBarMoved!;
    // The explicit callable type is the public compile-time contract under test.
    // ignore: omit_local_variable_types
    final void Function(Object, String, String?, double) drop = edit.onForeignLaneDrop!;
    expect(tapped, same(barTapped));
    expect(marquee, same(barsMarqueed));
    expect(move, same(barMoved));
    expect(drop, same(foreignLaneDrop));
    // The explicit callable type is the public compile-time contract under test.
    // ignore: omit_local_variable_types
    final ValueChanged<double>? scrub = navigation.onScrub;
    expect(scrub, isNull);
  });
}
