import 'dart:ui' show Color, Image;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_diamond.dart';
import 'package:meta/meta.dart';

// obers_ui upstream candidate: one bar on a generic multi-track timeline,
// free of any document model.

/// One bar on a `TimelineTrack`: a colored span of frames with an optional
/// easing sketch, badge, and diamond markers.
///
/// Frames are doubles so any host — animation spans, clip lanes, audio
/// regions — can position bars without committing to a frame grid; hosts
/// that live on whole frames simply pass whole numbers.
@immutable
final class TimelineBar {
  /// Creates a bar spanning [start] to [end] frames, painted in [color].
  const TimelineBar({
    required this.id,
    required this.start,
    required this.end,
    required this.color,
    this.easing,
    this.badge,
    this.diamonds = const [],
    this.violation = false,
    this.thumbnails = const [],
  }) : assert(end >= start, 'end must be >= start');

  /// The bar's identity in interaction callbacks.
  final String id;

  /// The first frame the bar covers.
  final double start;

  /// The frame the bar ends on (exclusive).
  final double end;

  /// The bar's fill color (the host encodes meaning — phase, lane kind).
  final Color color;

  /// The curve sketched inside the bar as a small polyline, or `null` for
  /// no sketch.
  final Curve? easing;

  /// A short text drawn inside the bar when it is wide enough, or `null`.
  final String? badge;

  /// The diamond markers riding the bar (keyframe stops, beats), in paint
  /// order. Empty for a plain bar.
  final List<TimelineDiamond> diamonds;

  /// Whether the host flags this bar as violating (painted as a warning
  /// outline; the host explains why elsewhere).
  final bool violation;

  /// The filmstrip frames drawn inside this bar, in frame order.
  ///
  /// Given rather than fetched. Decoding video is the host's job — it knows
  /// the proxy tier and the cache — and a widget that started decodes would
  /// start them again on every rebuild.
  final List<TimelineThumbnail> thumbnails;

  /// How many frames the bar covers.
  double get durationFrames => end - start;

  @override
  bool operator ==(Object other) =>
      other is TimelineBar &&
      other.id == id &&
      other.start == start &&
      other.end == end &&
      other.color == color &&
      other.easing == easing &&
      other.badge == badge &&
      other.violation == violation &&
      listEquals(other.diamonds, diamonds) &&
      listEquals(other.thumbnails, thumbnails);

  @override
  int get hashCode => Object.hash(
    TimelineBar,
    id,
    start,
    end,
    color,
    easing,
    badge,
    violation,
    Object.hashAll(diamonds),
    Object.hashAll(thumbnails),
  );

  @override
  String toString() => 'TimelineBar($id, $start..$end)';
}

/// One filmstrip frame: the composition frame it stands for and the decoded
/// image to draw there.
@immutable
final class TimelineThumbnail {
  /// A thumbnail of [frame].
  const TimelineThumbnail(this.frame, this.image);

  /// The composition frame this image was decoded at.
  final double frame;

  /// The decoded image, at whatever resolution the host chose.
  final Image image;

  @override
  bool operator ==(Object other) =>
      other is TimelineThumbnail && other.frame == frame && identical(other.image, image);

  @override
  int get hashCode => Object.hash(frame, image);

  @override
  String toString() => 'TimelineThumbnail($frame)';
}
