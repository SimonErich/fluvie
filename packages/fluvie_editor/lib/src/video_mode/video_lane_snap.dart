import 'dart:math' as math;

import 'package:fluvie_editor/src/timeline/timeline_snap.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_bar.dart';

/// How many pixels of pointer slack a snap is worth.
///
/// Pixels rather than frames, because the hand works in pixels: at eight the
/// catch is reachable without being sticky, and it stays the same distance on
/// screen however far the timeline is zoomed.
const double _snapSlopPixels = 8;

/// [_snapSlopPixels] expressed in frames at [pixelsPerFrame].
///
/// Never below one frame. A zero tolerance at high zoom would make snapping
/// unreachable by hand, which reads as the feature being broken rather than as
/// it being precise.
int snapToleranceFrames(double pixelsPerFrame) =>
    math.max(1, (_snapSlopPixels / pixelsPerFrame).round());

/// The snap candidates a drag on the video timeline can catch on: the
/// playhead, every scene boundary, and every other bar's edges.
///
/// Frame zero needs no candidate of its own — the first scene begins there and
/// already anchors it, and a second candidate on the same frame would only
/// fight it for the tie and rename the same line.
///
/// Read from the same [VideoLaneModel] the lanes are drawn from, so a bar can
/// only ever snap to something the author can see. The dragged bar's own edges
/// are left out — a bar that snapped to itself could never be nudged off.
///
/// Scene blocks are read as boundaries rather than as bar edges even though
/// the scenes lane draws them as bars, because they are the cut: ranking a
/// block above the boundary it represents would put a label the author never
/// placed ahead of the edit they did.
TimelineSnapEngine videoLaneSnapEngine(
  VideoLaneModel model, {
  required String draggedBarId,
  required int playhead,
  required double pixelsPerFrame,
}) => TimelineSnapEngine(
  tolerance: snapToleranceFrames(pixelsPerFrame),
  candidates: [
    TimelineSnapCandidate(playhead, TimelineSnapKind.playhead),
    for (final span in model.timebase.sceneSpans) ...[
      TimelineSnapCandidate(span.start, TimelineSnapKind.sceneBoundary),
      TimelineSnapCandidate(span.end, TimelineSnapKind.sceneBoundary),
    ],
    for (final track in model.tracks)
      for (final bar in track.bars)
        if (bar.id != draggedBarId && _isMaterial(model, bar.id)) ...[
          TimelineSnapCandidate(bar.start.round(), TimelineSnapKind.barEdge),
          TimelineSnapCandidate(bar.end.round(), TimelineSnapKind.barEdge),
        ],
  ],
);

/// Whether [barId] is real material — a clip, a window, or an audio track —
/// rather than a scene block.
bool _isMaterial(VideoLaneModel model, String barId) =>
    model.elementBars.containsKey(barId) || model.audioBars.containsKey(barId);

/// The bar with [barId] on any lane, or null when the id names no bar (a
/// keyframe diamond, or a bar that has since been removed).
TimelineBar? videoBarById(VideoLaneModel model, String barId) {
  for (final track in model.tracks) {
    for (final bar in track.bars) {
      if (bar.id == barId) return bar;
    }
  }
  return null;
}
