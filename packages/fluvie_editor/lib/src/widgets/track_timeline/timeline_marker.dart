import 'package:meta/meta.dart';

// obers_ui upstream candidate: one ruler marker of a generic multi-track
// timeline, free of any document model.

/// One vertical marker on a `TrackTimeline` ruler: a draggable divider at
/// [frame] with an optional [label].
///
/// The widget knows nothing about what a marker means — the host encodes
/// meaning (a build step, a chapter, a cue) and hears moves, insertions,
/// and removals back through the marker callbacks.
@immutable
final class TimelineMarker {
  /// Creates a marker sitting on [frame].
  const TimelineMarker({required this.id, required this.frame, this.label});

  /// The marker's identity in interaction callbacks.
  final String id;

  /// The frame the marker divides.
  final double frame;

  /// A short text drawn beside the marker line, or `null` for none.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is TimelineMarker && other.id == id && other.frame == frame && other.label == label;

  @override
  int get hashCode => Object.hash(TimelineMarker, id, frame, label);

  @override
  String toString() => 'TimelineMarker($id @ $frame)';
}
