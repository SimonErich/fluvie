import 'package:meta/meta.dart';

// obers_ui upstream candidate: one marker on a generic timeline bar, free
// of any document model.

/// One diamond marker riding a `TimelineBar`: a draggable point of
/// interest at [frame].
///
/// The widget knows nothing about what a diamond means — the host encodes
/// meaning (a keyframe stop, a beat, a chapter mark) and hears edits back
/// through the diamond callbacks.
@immutable
final class TimelineDiamond {
  /// Creates a diamond sitting on [frame].
  const TimelineDiamond({required this.id, required this.frame});

  /// The diamond's identity in interaction callbacks.
  final String id;

  /// The frame the diamond marks (in the same axis as its bar).
  final double frame;

  @override
  bool operator ==(Object other) =>
      other is TimelineDiamond && other.id == id && other.frame == frame;

  @override
  int get hashCode => Object.hash(TimelineDiamond, id, frame);

  @override
  String toString() => 'TimelineDiamond($id @ $frame)';
}
