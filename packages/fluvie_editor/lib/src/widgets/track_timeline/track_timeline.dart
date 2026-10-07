import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/widgets/numeric_unit.dart' show formatTimecode;
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_bar.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_diamond.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_lane_rows.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_link.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_marker.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_track.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/track_timeline_controller.dart';
import 'package:obers_ui/obers_ui.dart';

part 'track_timeline_diamonds.dart';
part 'track_timeline_labels.dart';
part 'track_timeline_lanes.dart';
part 'track_timeline_lane_geometry.dart';
part 'track_timeline_lane_surface.dart';
part 'track_timeline_links.dart';
part 'track_timeline_markers.dart';
part 'track_timeline_overlays.dart';
part 'track_timeline_painters.dart';
part 'track_timeline_lane_content.dart';
part 'track_timeline_ruler.dart';
part 'track_timeline_ruler_painter.dart';
part 'track_timeline_state.dart';

// obers_ui upstream candidate: a scrubbable multi-track timeline widget,
// free of any document model — hosts feed it tracks and hear edits back.

part 'track_timeline_selection.dart';
part 'track_timeline_navigation.dart';
part 'track_timeline_edit_actions.dart';
part 'track_timeline_overlay_actions.dart';
part 'track_timeline_lane_actions.dart';
part 'track_timeline_appearance.dart';

/// A scrubbable multi-track timeline: a seconds ruler over labeled lanes of
/// draggable bars, with a playhead, horizontal zoom, and collapsible groups.
///
/// The widget knows nothing about what a track or bar means. It reports
/// intentions — a bar moved, an edge trimmed, a diamond dragged, the ruler
/// scrubbed — through callbacks and never mutates its own model; the host
/// re-renders it with new [TrackTimeline.tracks] when its document changes. An empty
/// [TrackTimeline.tracks] list shows [TrackTimelineAppearance.emptyMessage] plus the [TrackTimelineAppearance.emptyAction] slot, so empty
/// is never a dead end.
final class TrackTimeline extends StatefulWidget {
  /// Shows [TrackTimeline.tracks] over [TrackTimeline.totalFrames] frames at [TrackTimeline.fps].
  const TrackTimeline({
    required this.tracks,
    required this.fps,
    required this.totalFrames,
    this.playhead = 0,
    this.controller,
    this.links = const [],
    this.markers = const [],
    this.snapFrame,
    this.onFilmstripNeeded,
    this.selection = const TrackTimelineSelection(),
    this.navigation = const TrackTimelineNavigation(),
    this.edit = const TrackTimelineEditActions(),
    this.overlays = const TrackTimelineOverlayActions(),
    this.lanes = const TrackTimelineLaneActions(),
    this.appearance = const TrackTimelineAppearance(),
    super.key,
  });

  /// The rows, top to bottom (group children follow their group, deeper).
  final List<TimelineTrack> tracks;

  /// Frames per second — how the ruler turns frames into second labels.
  final double fps;

  /// The timeline's length in frames; the lane beyond it is shaded.
  final double totalFrames;

  /// The playhead position in frames.
  final double playhead;

  /// Zoom and collapse state; `null` and the widget owns one internally.
  final TrackTimelineController? controller;

  /// The elbow connectors drawn between bars, in paint order. A link whose
  /// bars sit on hidden (collapsed) rows is skipped.
  final List<TimelineLink> links;

  /// The vertical markers riding the ruler, in paint order.
  final List<TimelineMarker> markers;

  /// The frame a drag has snapped to, drawn as a guide across the lanes, or
  /// `null` for none.
  ///
  /// Host state, like [TrackTimeline.playhead] and [TrackTimelineSelection.selectedTrackIds]: the host owns the
  /// snapping rule and this widget only paints where it landed, so one decider
  /// owns what "close enough" means at any zoom.
  final double? snapFrame;

  /// Hears the frame span the lanes can currently show, whenever it changes.
  ///
  /// A filmstrip is asked for lazily and only for what is on screen: decoding
  /// a whole project's frames to draw a strip nobody scrolled to is the one
  /// cost a timeline cannot afford. The host answers by handing back bars with
  /// thumbnails; it is never called twice for the same span.
  final void Function(int fromFrame, int toFrame)? onFilmstripNeeded;

  /// Host-owned selected tracks, bars, overlays and frame range.
  final TrackTimelineSelection selection;

  /// Selection and frame-navigation intentions; no document mutation.
  final TrackTimelineNavigation navigation;

  /// Bar edits, cross-artifact drag lifecycle and external-drop intentions.
  final TrackTimelineEditActions edit;

  /// Diamond, connector and ruler-marker editing intentions.
  final TrackTimelineOverlayActions overlays;

  /// Reorder, lock, mute and monitoring-solo intentions for lane labels.
  final TrackTimelineLaneActions lanes;

  /// Static row/ruler geometry and the empty-state presentation.
  final TrackTimelineAppearance appearance;

  @override
  State<TrackTimeline> createState() => _TrackTimelineState();
}
