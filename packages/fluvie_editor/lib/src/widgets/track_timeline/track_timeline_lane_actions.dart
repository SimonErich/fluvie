part of 'track_timeline.dart';

/// Reorder, lock, mute and monitoring-solo intentions for lane labels.
final class TrackTimelineLaneActions {
  /// Configures lanes without side effects or callback wrapping.
  const TrackTimelineLaneActions({
    this.onLaneReordered,
    this.onLaneLockToggled,
    this.onLaneMuteToggled,
    this.onLaneSoloToggled,
  });

  /// Hears a lane's label dragged onto another row: the lane and the row it
  /// landed on. Null and labels do not drag at all.
  final void Function(String trackId, int toRow)? onLaneReordered;

  /// Hears the lock affordance tapped. Null and no lock is drawn: an
  /// affordance the host cannot serve is worse than no affordance.
  final ValueChanged<String>? onLaneLockToggled;

  /// Hears the mute affordance tapped (null hides it).
  final ValueChanged<String>? onLaneMuteToggled;

  /// Hears the solo affordance tapped (null hides it).
  final ValueChanged<String>? onLaneSoloToggled;
}
