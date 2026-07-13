import 'package:meta/meta.dart';

/// A half-open span of absolute video frames: [start] inclusive, [end]
/// exclusive — the introspection currency for windows, animations, and
/// scene bounds.
///
/// A plain value with full equality, so introspection results can be
/// compared and asserted directly:
///
/// ```dart
/// expect(element.window, const FrameSpan(0, 60));
/// ```
@immutable
final class FrameSpan {
  /// Creates a span from [start] (inclusive) to [end] (exclusive).
  const FrameSpan(this.start, this.end);

  /// The first frame of the span.
  final int start;

  /// The frame the span ends on (exclusive).
  final int end;

  /// How many frames the span covers: `end - start`.
  int get durationFrames => end - start;

  /// Whether [frame] lies inside the span.
  bool contains(int frame) => frame >= start && frame < end;

  @override
  bool operator ==(Object other) => other is FrameSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(FrameSpan, start, end);

  @override
  String toString() => 'FrameSpan($start..$end)';
}
