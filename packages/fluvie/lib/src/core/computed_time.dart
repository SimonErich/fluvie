part of 'time.dart';

/// A [Time] computed from the resolving scope — the internal variant behind
/// schedule-derived durations (a `Timeline` resolves at the enclosing
/// `Video`'s fps, so its times cannot be eager).
///
/// Deliberately not on the public barrel, and the spec codecs reject it: a
/// schedule-derived time has no serial form.
@internal
final class ComputedTime extends Time {
  /// Creates a time that resolves to `compute(scope)` frames.
  const ComputedTime(this.compute);

  /// Computes the resolved frame count for the resolving scope.
  final int Function(TimeScope scope) compute;

  @override
  int resolveFrames(TimeScope scope) => compute(scope);

  @override
  String toString() => 'Time.computed(<schedule>)';
}
