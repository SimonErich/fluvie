import 'package:fluvie/src/timing/timeline/timeline_anchor.dart';
import 'package:fluvie/src/timing/timeline/timeline_row.dart';
import 'package:meta/meta.dart';

/// The deterministic schedule of a whole composition: every animation as a
/// [TimelineRow] with absolute frames, plus any out-of-bounds [warnings].
///
/// Produced by `resolveComposition` as a pure function of the plan — the same
/// plan always yields an identical timeline, which is what makes timing
/// assertions, golden `debugTimeline` dumps, and frame caching possible.
@immutable
final class ResolvedTimeline {
  /// Creates a timeline; [rows] must already be sorted by
  /// `(startFrame, declaration index)`.
  const ResolvedTimeline({
    required this.fps,
    required this.totalFrames,
    required this.rows,
    this.anchors = const [],
    this.warnings = const [],
  });

  /// Frames per second of the whole render.
  final int fps;

  /// The video's total length in frames (the sum of its scenes).
  final int totalFrames;

  /// Every resolved animation, sorted by start frame (declaration order
  /// breaks ties).
  final List<TimelineRow> rows;

  /// Every named anchor in the composition, resolved to the frame its
  /// element's timeline starts on, in declaration order.
  ///
  /// The structured "jump to anchor" egress the inspector seeks against; empty
  /// when the composition declares no anchors. The string `debugTimeline`
  /// dump never lists anchors, so this is read straight, never parsed back.
  final List<TimelineAnchor> anchors;

  /// Human-readable bounds warnings, one per violation: a row lying outside
  /// its element window or outside the video span names its owner here, while
  /// its raw span stays untouched in [rows]. Empty when every
  /// row fits.
  final List<String> warnings;

  /// The rows belonging to the element identified by [ownerId], in timeline
  /// order; empty when the element has none.
  List<TimelineRow> rowsFor(String ownerId) => [
    for (final row in rows)
      if (row.ownerId == ownerId) row,
  ];

  @override
  String toString() =>
      'ResolvedTimeline(fps: $fps, totalFrames: $totalFrames, '
      'rows: ${rows.length}, warnings: ${warnings.length})';
}
