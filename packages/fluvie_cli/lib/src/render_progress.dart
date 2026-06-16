import 'package:meta/meta.dart';

/// How far a render has progressed: [completed] of [total] frames captured.
///
/// The capture harness writes `"<completed>/<total>"` to its progress file
/// every frame; [parseRenderProgress] turns that text into this snapshot so a
/// caller (the CLI poller, the render server's job status) can show live
/// progress without depending on Flutter.
@immutable
final class RenderProgress {
  /// Creates a progress snapshot.
  const RenderProgress({required this.completed, required this.total});

  /// Frames captured so far (rises from `0` to [total]).
  final int completed;

  /// The render's total frame count.
  final int total;

  /// Completion as a `0..1` fraction (`0` when [total] is not yet known).
  double get fraction => total <= 0 ? 0 : (completed / total).clamp(0.0, 1.0);

  /// Whether every frame is captured (the render is now encoding/finishing).
  bool get isComplete => total > 0 && completed >= total;

  @override
  bool operator ==(Object other) =>
      other is RenderProgress && other.completed == completed && other.total == total;

  @override
  int get hashCode => Object.hash(completed, total);

  @override
  String toString() => 'RenderProgress($completed/$total)';
}

/// Parses `"<completed>/<total>"` from [contents] (a progress file's text), or
/// `null` when it is not yet a complete `int/int` line.
///
/// A torn read mid-write (an empty or half-written file) returns `null` so the
/// caller simply retries on its next poll rather than reporting a bogus count.
RenderProgress? parseRenderProgress(String contents) {
  final parts = contents.trim().split('/');
  if (parts.length != 2) return null;
  final completed = int.tryParse(parts[0]);
  final total = int.tryParse(parts[1]);
  if (completed == null || total == null) return null;
  return RenderProgress(completed: completed, total: total);
}
