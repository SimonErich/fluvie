import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_scope.dart';

/// The decision-D13 guard: a [TimeScope] with a known fps but *no* window
/// length. Resolving any relative component against it throws [message] as a
/// [FluvieTimingError] — even when the relative part hides inside a composite
/// time produced by `+`, `-`, or `*`. Root video and scene durations both use
/// it: each defines the window everything else measures against, so a
/// relative value there would be a fraction of itself.
final class RelativeDurationGuard implements TimeScope {
  /// Creates a guard that throws [message] when a relative duration resolves.
  const RelativeDurationGuard(this.fps, this.message);

  @override
  final int fps;

  /// The error text thrown on relative resolution; names the offending owner.
  final String message;

  @override
  int get startFrame => 0;

  @override
  TimeScope? get parent => null;

  @override
  int get durationFrames => throw FluvieTimingError(message);
}
