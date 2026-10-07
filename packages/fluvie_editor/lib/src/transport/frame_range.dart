import 'package:meta/meta.dart';

/// A forward span of slide-relative frames — the timeline's range selection
/// and the transport's loop target.
///
/// The span runs from [start] up to [end]: [contains] is inclusive of the
/// start and exclusive of the end, so a playhead sitting exactly on [end]
/// has left the range (which is what lets a loop wrap there).
@immutable
final class FrameRange {
  /// Creates the span from [start] (>= 0) to [end] (> [start]).
  const FrameRange(this.start, this.end)
    : assert(start >= 0, 'start must be >= 0, got $start'),
      assert(end > start, 'the range must run forward, got $start..$end');

  /// The first frame inside the range.
  final int start;

  /// The frame the range stops on (exclusive).
  final int end;

  /// How many frames the range covers.
  int get lengthFrames => end - start;

  /// Whether [frame] sits inside the range (start inclusive, end exclusive).
  bool contains(int frame) => frame >= start && frame < end;

  @override
  bool operator ==(Object other) => other is FrameRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(FrameRange, start, end);

  @override
  String toString() => 'FrameRange($start..$end)';
}
