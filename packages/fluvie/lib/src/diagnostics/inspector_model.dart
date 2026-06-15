import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';
import 'package:fluvie/src/timing/timeline/timeline_anchor.dart';
import 'package:meta/meta.dart';

part 'inspector_motion.dart';

/// The whole resolved schedule as a plain, immutable value an inspector UI can
/// bind to: the [fps] and [totalFrames] of the render, every animation as an
/// [InspectorMotion], every named anchor as a [TimelineAnchor], and the timing
/// [warnings] the resolver collected.
///
/// Built by [InspectorModel.fromTimeline] from a [ResolvedTimeline] — the
/// value the embedder reads through the timeline probe. It is pure: no
/// `BuildContext`, no widgets, no IO, and the same timeline always
/// builds an equal model, so it is trivially testable and golden-stable. The
/// example app's `InspectorViewModel` consumes it; the library itself holds no
/// view models (the library lives in `diagnostics`, the top layer, so nothing
/// depends on this).
@immutable
final class InspectorModel {
  /// Creates a model directly from its parts; prefer [InspectorModel.fromTimeline].
  const InspectorModel({
    required this.fps,
    required this.totalFrames,
    required this.motions,
    required this.anchors,
    required this.warnings,
  });

  /// Builds the model from a resolved [timeline], mapping every row to an
  /// [InspectorMotion] and surfacing the timeline's structured anchors and
  /// warnings verbatim — the warnings are read straight off
  /// [ResolvedTimeline.warnings], never parsed back from a `debugTimeline`
  /// table dump.
  factory InspectorModel.fromTimeline(ResolvedTimeline timeline) => InspectorModel(
    fps: timeline.fps,
    totalFrames: timeline.totalFrames,
    motions: List.unmodifiable([
      for (final row in timeline.rows)
        InspectorMotion(
          ownerId: row.ownerId,
          label: row.label,
          phase: row.phase,
          startFrame: row.startFrame,
          endFrame: row.endFrame,
        ),
    ]),
    anchors: List.unmodifiable(timeline.anchors),
    warnings: List.unmodifiable(timeline.warnings),
  );

  /// Frames per second of the whole render.
  final int fps;

  /// The video's total length in frames.
  final int totalFrames;

  /// Every resolved animation, in timeline order (start frame, then
  /// declaration order).
  final List<InspectorMotion> motions;

  /// Every named anchor, resolved to the frame its element's timeline starts
  /// on — the "jump to anchor" targets.
  final List<TimelineAnchor> anchors;

  /// The resolver's timing warnings, one per bounds violation; empty when
  /// every motion fits.
  final List<String> warnings;

  @override
  bool operator ==(Object other) =>
      other is InspectorModel &&
      other.fps == fps &&
      other.totalFrames == totalFrames &&
      _listEquals(other.motions, motions) &&
      _listEquals(other.anchors, anchors) &&
      _listEquals(other.warnings, warnings);

  @override
  int get hashCode => Object.hash(
    InspectorModel,
    fps,
    totalFrames,
    Object.hashAll(motions),
    Object.hashAll(anchors),
    Object.hashAll(warnings),
  );

  @override
  String toString() =>
      'InspectorModel(fps: $fps, totalFrames: $totalFrames, motions: ${motions.length}, '
      'anchors: ${anchors.length}, warnings: ${warnings.length})';
}

/// Order-sensitive list equality for the model's value semantics. Hand-rolled
/// on purpose: it keeps this model free of any Flutter/foundation import so it
/// depends only on core + timing, per the layering law.
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
