/// Information about a sync anchor's timing in the composition.
///
/// This data class stores the resolved timing information for a [SyncAnchor]
/// widget, allowing other animations and audio tracks to synchronize with it.
class SyncAnchorInfo {
  /// The unique identifier for this anchor.
  final String anchorId;

  /// The frame at which this anchor becomes active.
  final int startFrame;

  /// The frame at which this anchor ends.
  ///
  /// May be null if the anchor has no defined end.
  final int? endFrame;

  /// Creates sync anchor info.
  const SyncAnchorInfo({
    required this.anchorId,
    required this.startFrame,
    this.endFrame,
  });

  /// The duration in frames, or null if no end frame is defined.
  int? get durationInFrames {
    if (endFrame == null) return null;
    return endFrame! - startFrame;
  }

  /// Returns the start frame with an optional offset.
  int startFrameWithOffset(int offset) => startFrame + offset;

  /// Returns the end frame with an optional offset.
  ///
  /// Returns null if no end frame is defined.
  int? endFrameWithOffset(int offset) {
    if (endFrame == null) return null;
    return endFrame! + offset;
  }

  @override
  String toString() =>
      'SyncAnchorInfo(id: $anchorId, start: $startFrame, end: $endFrame)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncAnchorInfo &&
          runtimeType == other.runtimeType &&
          anchorId == other.anchorId &&
          startFrame == other.startFrame &&
          endFrame == other.endFrame;

  @override
  int get hashCode => Object.hash(anchorId, startFrame, endFrame);
}
