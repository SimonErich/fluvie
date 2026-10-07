part of 'track_timeline.dart';

/// Diamond, connector and ruler-marker editing intentions.
final class TrackTimelineOverlayActions {
  /// Configures overlays without side effects or callback wrapping.
  const TrackTimelineOverlayActions({
    this.onDiamondTapped,
    this.onDiamondMoved,
    this.onDiamondDeleted,
    this.onLinkDropped,
    this.onLinkTapped,
    this.onLinkDeleted,
    this.onMarkerMoved,
    this.onMarkerInserted,
    this.onMarkerRemoved,
    this.onMarkerTapped,
  });

  /// Hears a tap on a diamond (the bar it rides and the diamond).
  final void Function(String barId, String diamondId)? onDiamondTapped;

  /// Hears a diamond drag: its would-be new frame, clamped to the bar span.
  final void Function(String barId, String diamondId, double frame)? onDiamondMoved;

  /// Hears Delete or Backspace while [TrackTimelineSelection.selectedDiamondId] names a diamond
  /// and the lanes hold keyboard focus (a tap focuses them).
  final void Function(String barId, String diamondId)? onDiamondDeleted;

  /// Hears a link-handle drag released over another bar.
  final void Function(String fromBarId, String toBarId)? onLinkDropped;

  /// Hears a tap on a link's connector.
  final ValueChanged<String>? onLinkTapped;

  /// Hears Delete while [TrackTimelineSelection.selectedLinkId] names a link (lanes focused).
  final ValueChanged<String>? onLinkDeleted;

  /// Hears a marker drag: its would-be new frame (clamped to the timeline).
  final void Function(String id, double frame)? onMarkerMoved;

  /// Hears a double tap on empty ruler space: the frame under it.
  final ValueChanged<double>? onMarkerInserted;

  /// Hears a marker dragged off the ruler, and Delete while
  /// [TrackTimelineSelection.selectedMarkerId] names a marker (lanes focused).
  final ValueChanged<String>? onMarkerRemoved;

  /// Hears a tap on a marker.
  final ValueChanged<String>? onMarkerTapped;
}
