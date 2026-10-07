import 'dart:ui' show Color;

import 'package:meta/meta.dart';

// obers_ui upstream candidate: one connector between two bars of a generic
// multi-track timeline, free of any document model.

/// Which edge of the target bar a [TimelineLink] lands on.
enum TimelineLinkEdge {
  /// The connector attaches to the target bar's start edge.
  start,

  /// The connector attaches to the target bar's end edge.
  end,
}

/// One connector on a `TrackTimeline`: an elbow drawn from the start edge of
/// the bar [fromBarId] to the [toEdge] of the bar [toBarId].
///
/// The widget knows nothing about what a link means — the host encodes
/// meaning (a trigger, a dependency, a sync point) and hears taps, drops,
/// and deletions back through the link callbacks.
@immutable
final class TimelineLink {
  /// Creates a link from bar [fromBarId] to bar [toBarId].
  const TimelineLink({
    required this.id,
    required this.fromBarId,
    required this.toBarId,
    required this.toEdge,
    required this.color,
    this.label,
  });

  /// The link's identity in interaction callbacks.
  final String id;

  /// The bar the connector starts from (its start edge).
  final String fromBarId;

  /// The bar the connector lands on.
  final String toBarId;

  /// Which edge of [toBarId] the connector attaches to.
  final TimelineLinkEdge toEdge;

  /// The connector's stroke color (the host encodes meaning).
  final Color color;

  /// A short text drawn along the connector, or `null` for none.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is TimelineLink &&
      other.id == id &&
      other.fromBarId == fromBarId &&
      other.toBarId == toBarId &&
      other.toEdge == toEdge &&
      other.color == color &&
      other.label == label;

  @override
  int get hashCode => Object.hash(TimelineLink, id, fromBarId, toBarId, toEdge, color, label);

  @override
  String toString() => 'TimelineLink($id, $fromBarId -> $toBarId.${toEdge.name})';
}
