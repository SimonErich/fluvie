import 'package:fluvie/rendering.dart' show WaveformEnvelope;
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_bar.dart';
import 'package:meta/meta.dart';

// obers_ui upstream candidate: one row of a generic multi-track timeline,
// free of any document model.

/// One row of a `TrackTimeline`: a labeled lane holding [bars].
///
/// Rows form a flat list; [depth] indents a row under the nearest preceding
/// row of a smaller depth, and a row with [isGroup] can collapse everything
/// deeper that follows it. The widget stays ignorant of what a track means —
/// an element, a clip lane, an audio bus.
@immutable
final class TimelineTrack {
  /// Creates a track labeled [label] holding [bars].
  const TimelineTrack({
    required this.id,
    required this.label,
    this.depth = 0,
    this.isGroup = false,
    this.bars = const [],
    this.height,
    this.locked = false,
    this.muted = false,
    this.soloed = false,
    this.envelope,
    this.showLaneControls = true,
  }) : assert(depth >= 0, 'depth must be >= 0'),
       assert(height == null || height > 0, 'a lane with no height cannot be seen');

  /// The track's identity in interaction callbacks.
  final String id;

  /// The name shown in the labels column.
  final String label;

  /// How deep the row indents (0 = top level, 1 = inside one group, ...).
  final int depth;

  /// Whether the row heads a collapsible run of deeper rows.
  final bool isGroup;

  /// The bars on this lane, in paint order.
  final List<TimelineBar> bars;

  /// How tall this row is, or null for the timeline's default. A waveform or
  /// a filmstrip wants room; an empty lane does not.
  final double? height;

  /// Whether the host treats this lane as locked. The widget paints the state
  /// and reports the toggle; what a lock forbids is the host's business.
  final bool locked;

  /// Whether the host treats this lane as muted.
  final bool muted;

  /// Whether the host treats this lane as soloed.
  final bool soloed;

  /// The audio shape drawn behind this lane's bars, or null for none.
  ///
  /// Given rather than fetched: decoding audio is the host's job, and a widget
  /// that started decodes would do it again on every rebuild.
  final WaveformEnvelope? envelope;

  /// Whether lock/mute/solo chrome applies to this row. Structural chapter
  /// and effect subrows can opt out while declared lanes keep their controls.
  final bool showLaneControls;

  /// This row with [bars] in place of its own.
  TimelineTrack withBars(List<TimelineBar> bars) => TimelineTrack(
    id: id,
    label: label,
    depth: depth,
    isGroup: isGroup,
    bars: bars,
    height: height,
    locked: locked,
    muted: muted,
    soloed: soloed,
    envelope: envelope,
    showLaneControls: showLaneControls,
  );

  @override
  String toString() => 'TimelineTrack($id, $label, depth: $depth, bars: ${bars.length})';
}
