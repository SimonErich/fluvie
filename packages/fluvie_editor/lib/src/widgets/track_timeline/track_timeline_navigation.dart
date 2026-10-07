part of 'track_timeline.dart';

/// Selection and frame-navigation intentions; no document mutation.
final class TrackTimelineNavigation {
  /// Configures navigation without side effects or callback wrapping.
  const TrackTimelineNavigation({
    this.onScrub,
    this.onLabelTapped,
    this.onRangeSelected,
    this.onRangeCleared,
    this.onBarTapped,
    this.onBarsMarqueed,
    this.onTrackTapped,
  });

  /// Hears ruler scrubs (frames, clamped to `0..totalFrames`).
  final ValueChanged<double>? onScrub;

  /// Hears a tap on a track's label name (distinct from the collapse
  /// chevron): the host selects the track's element. Reserved for selection —
  /// [TrackTimelineNavigation.onTrackTapped] keeps the lane's scrub and keyframe duty.
  final ValueChanged<String>? onLabelTapped;

  /// Hears a shift-drag on the ruler as a forward frame range (clamped to
  /// the timeline; a motionless press reports nothing). Shift-drag beats
  /// the marker and scrub gestures on the ruler; everything else keeps its
  /// priority.
  final void Function(double start, double end)? onRangeSelected;

  /// Hears Escape while [TrackTimelineSelection.rangeSelection] names a range (lanes focused — a
  /// range drag or any lane tap focuses them).
  final VoidCallback? onRangeCleared;

  /// Hears a tap on a bar, and whether a modifier asked to add it to the
  /// selection rather than replace it.
  ///
  /// Shift and Ctrl both read as additive. Neither means "select the range
  /// between": on a surface with two axes the honest range gesture is the
  /// rubber band, and one modifier cannot mean both.
  final void Function(String barId, {required bool additive})? onBarTapped;

  /// Hears a rubber band drawn across empty lane space: every bar it touched,
  /// and whether Shift asked to extend rather than replace.
  ///
  /// An empty set is reported too, because a band that caught nothing plainly
  /// means "none of these" and a host that heard nothing would keep a stale
  /// selection behind it.
  final void Function(Set<String> barIds, {required bool additive})? onBarsMarqueed;

  /// Hears a tap on empty lane space: the track and the frame under it.
  final void Function(String trackId, double frame)? onTrackTapped;
}
