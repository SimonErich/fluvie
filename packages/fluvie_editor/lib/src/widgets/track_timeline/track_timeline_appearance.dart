part of 'track_timeline.dart';

/// Static row/ruler geometry and the empty-state presentation.
final class TrackTimelineAppearance {
  /// Configures appearance without side effects or callback wrapping.
  const TrackTimelineAppearance({
    this.emptyMessage = 'Nothing here yet.',
    this.emptyAction,
    this.labelWidth = 140,
    this.trackHeight = 28,
    this.rulerHeight = 24,
  });

  /// The single line an empty timeline explains itself with.
  final String emptyMessage;

  /// An optional widget next to [TrackTimelineAppearance.emptyMessage] (typically an add action).
  final Widget? emptyAction;

  /// The width of the labels column.
  final double labelWidth;

  /// The height of one lane row.
  final double trackHeight;

  /// The height of the ruler strip.
  final double rulerHeight;
}
