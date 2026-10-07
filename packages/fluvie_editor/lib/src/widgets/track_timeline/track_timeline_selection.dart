part of 'track_timeline.dart';

/// Host-owned selected tracks, bars, overlays and frame range.
final class TrackTimelineSelection {
  /// Configures selection without side effects or callback wrapping.
  const TrackTimelineSelection({
    this.selectedDiamondId,
    this.selectedLinkId,
    this.selectedMarkerId,
    this.selectedTrackIds = const {},
    this.selectedBarIds = const {},
    this.rangeSelection,
  });

  /// The diamond painted as selected, or `null` for none. Selection is host
  /// state: the widget only reports taps and paints the highlight.
  final String? selectedDiamondId;

  /// The link painted as selected, or `null` for none (host state).
  final String? selectedLinkId;

  /// The marker painted as selected, or `null` for none (host state).
  final String? selectedMarkerId;

  /// The track ids painted as selected: each fills its lane row and tints its
  /// label. Selection is host state — the widget only paints what it is given
  /// and reports label taps through [TrackTimelineNavigation.onLabelTapped].
  final Set<String> selectedTrackIds;

  /// The bar ids painted as selected: each takes a bright outline. Selection
  /// is host state — the widget reports clicks through [TrackTimelineNavigation.onBarTapped] and
  /// rubber bands through [TrackTimelineNavigation.onBarsMarqueed], and paints what it is given.
  final Set<String> selectedBarIds;

  /// The frame range painted as selected across the ruler and the lanes,
  /// or `null` for none. Selection is host state: the widget reports
  /// shift-drags through [TrackTimelineNavigation.onRangeSelected] and paints what it is given.
  final ({double start, double end})? rangeSelection;
}
