part of 'inspector_model.dart';

/// One resolved animation as the inspector shows it: who animates ([ownerId]),
/// what it is called ([label]), when it plays ([phase]), the absolute frame
/// span it occupies, and the [jumpFrame] the preview seeks to when the row is
/// tapped.
///
/// A pure value with full equality — the inspector's motion rows compare,
/// snapshot, and golden-test directly. It mirrors a `TimelineRow` plus the one
/// derived field an inspector UI needs: [jumpFrame] (the span start).
@immutable
final class InspectorMotion {
  /// Creates a motion row; [label] is `null` for an unlabelled animation.
  const InspectorMotion({
    required this.ownerId,
    required this.phase,
    required this.startFrame,
    required this.endFrame,
    this.label,
  });

  /// The owning element's stable identifier (`s<scene>e<order>:<owner>`).
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

  /// The frame "jump to motion" seeks the preview to — the span start.
  int get jumpFrame => startFrame;

  @override
  bool operator ==(Object other) =>
      other is InspectorMotion &&
      other.ownerId == ownerId &&
      other.label == label &&
      other.phase == phase &&
      other.startFrame == startFrame &&
      other.endFrame == endFrame;

  @override
  int get hashCode => Object.hash(InspectorMotion, ownerId, label, phase, startFrame, endFrame);

  @override
  String toString() {
    final name = label == null ? '' : '$label, ';
    return 'InspectorMotion($ownerId, $name${phase.name}, $startFrame..$endFrame)';
  }
}
