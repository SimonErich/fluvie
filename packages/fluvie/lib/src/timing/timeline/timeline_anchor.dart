/// @docImport 'package:fluvie/src/core/anchor.dart';
library;

import 'package:meta/meta.dart';

/// One resolved anchor in the timeline: an [Anchor]'s diagnostic [name] and the
/// absolute video [frame] its element's timeline starts on.
///
/// Anchors are the structured egress behind "jump to trigger" — the inspector
/// lists them and seeks the preview to [frame]. The value is pure with full
/// equality so resolved timelines can be compared and golden-tested directly.
///
/// [name] is the anchor's `debugName`, or `Anchor#<hash>` when it was created
/// without one (see `Anchor.toString`); it carries no semantic weight.
@immutable
final class TimelineAnchor {
  /// Creates an anchor row at [frame], named [name].
  const TimelineAnchor({required this.name, required this.frame});

  /// The anchor's diagnostic name (its `Anchor.debugName`, or the synthetic
  /// `Anchor#<hash>` form when it was unnamed).
  final String name;

  /// The first absolute video frame of the anchored element's timeline — the
  /// frame "jump to anchor" seeks the preview to.
  final int frame;

  @override
  bool operator ==(Object other) =>
      other is TimelineAnchor && other.name == name && other.frame == frame;

  @override
  int get hashCode => Object.hash(TimelineAnchor, name, frame);

  @override
  String toString() => 'TimelineAnchor($name @ $frame)';
}
