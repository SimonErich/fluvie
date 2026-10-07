import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_track.dart';

// obers_ui upstream candidate: the view-state of a generic multi-track
// timeline — horizontal zoom and collapsed groups — plus its pure math.

/// The `TrackTimeline` view-state a host can drive programmatically:
/// horizontal zoom (pixels per frame) and which group rows are collapsed.
///
/// The widget owns one internally when none is passed; pass a controller to
/// wire zoom commands or to pre-collapse groups.
final class TrackTimelineController extends ChangeNotifier {
  /// Creates the view-state at [pixelsPerFrame] zoom (clamped to the range).
  TrackTimelineController({double pixelsPerFrame = 4})
    : _pixelsPerFrame = _clampZoom(pixelsPerFrame);

  /// The smallest zoom: half a pixel per frame (a minute of 30fps in ~900px).
  static const double minPixelsPerFrame = 0.5;

  /// The largest zoom: forty pixels per frame (frame-accurate trimming).
  static const double maxPixelsPerFrame = 40;

  /// The multiplicative step [zoomIn] and [zoomOut] take.
  static const double zoomStep = 1.25;

  double _pixelsPerFrame;
  final Set<String> _collapsed = {};

  /// How many horizontal pixels one frame occupies.
  double get pixelsPerFrame => _pixelsPerFrame;

  set pixelsPerFrame(double value) {
    final next = _clampZoom(value);
    if (next == _pixelsPerFrame) return;
    _pixelsPerFrame = next;
    notifyListeners();
  }

  /// Zooms in by one [zoomStep].
  void zoomIn() => pixelsPerFrame = _pixelsPerFrame * zoomStep;

  /// Zooms out by one [zoomStep].
  void zoomOut() => pixelsPerFrame = _pixelsPerFrame / zoomStep;

  /// The ids of the collapsed group rows (an unmodifiable view).
  Set<String> get collapsed => Set.unmodifiable(_collapsed);

  /// Whether the group row [id] is collapsed.
  bool isCollapsed(String id) => _collapsed.contains(id);

  /// Collapses or expands the group row [id].
  void toggleCollapsed(String id) {
    if (!_collapsed.remove(id)) _collapsed.add(id);
    notifyListeners();
  }

  /// The horizontal scroll that keeps the frame under the cursor stationary
  /// across a zoom from [from] to [to] pixels per frame, given the current
  /// [scrollX] and the cursor at [cursorDx] pixels into the lane viewport.
  static double zoomedScroll({
    required double scrollX,
    required double cursorDx,
    required double from,
    required double to,
  }) => math.max(0, (scrollX + cursorDx) * (to / from) - cursorDx);

  /// The rows the timeline shows: [tracks] minus every row hidden under a
  /// collapsed group — a run of rows deeper than the group is skipped
  /// wholesale, nested collapse state included.
  static List<TimelineTrack> visibleTracks(List<TimelineTrack> tracks, Set<String> collapsed) {
    final visible = <TimelineTrack>[];
    int? hiddenBelow;
    for (final track in tracks) {
      if (hiddenBelow != null && track.depth > hiddenBelow) continue;
      hiddenBelow = null;
      visible.add(track);
      if (track.isGroup && collapsed.contains(track.id)) hiddenBelow = track.depth;
    }
    return visible;
  }

  static double _clampZoom(double value) => value.clamp(minPixelsPerFrame, maxPixelsPerFrame);
}
