import 'package:fluvie/src/core/animation_phase.dart';
import 'package:meta/meta.dart';

/// One resolved animation in the timeline: who animates, what the animation
/// is called, when it plays, and the absolute frame span it occupies.
///
/// Rows are the output currency of `resolveComposition` — pure values with
/// full equality, so resolved timelines can be compared, snapshotted, and
/// golden-tested directly. Spans are raw placement results: a row may
/// overhang its element window or the video; out-of-bounds rows surface as
/// warnings on the timeline, never as silently clamped spans.
@immutable
final class TimelineRow {
  /// Creates a row; [label] is `null` for an unlabelled animation.
  const TimelineRow({
    required this.ownerId,
    required this.phase,
    required this.startFrame,
    required this.endFrame,
    this.label,
  });

  /// The owning element's stable identifier (its `ElementPlan.ownerId`).
  final String ownerId;

  /// The animation's diagnostic label, or `null` when it has none.
  final String? label;

  /// When the animation plays within its element's window.
  final AnimationPhase phase;

  /// The first absolute video frame of the span (inclusive).
  final int startFrame;

  /// The absolute video frame the span ends on (exclusive).
  final int endFrame;

  /// How many frames the span covers: `endFrame - startFrame`.
  int get durationFrames => endFrame - startFrame;

  @override
  bool operator ==(Object other) =>
      other is TimelineRow &&
      other.ownerId == ownerId &&
      other.label == label &&
      other.phase == phase &&
      other.startFrame == startFrame &&
      other.endFrame == endFrame;

  @override
  int get hashCode => Object.hash(TimelineRow, ownerId, label, phase, startFrame, endFrame);

  @override
  String toString() {
    final name = label == null ? '' : '$label, ';
    return 'TimelineRow($ownerId, $name${phase.name}, $startFrame..$endFrame)';
  }
}
