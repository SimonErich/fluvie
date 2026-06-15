import 'package:fluvie/fluvie.dart';

/// A const [TimeScope] reporting fixed values for all four contract members.
///
/// Unit tests resolve [Time] values against this fake without pumping a
/// widget tree. The engine's real scope is `TimeScopeData` in `timing/`; this
/// fixture is for tests that only need a scope's numbers.
class FixedTimeScope implements TimeScope {
  /// Creates a scope that always reports [fps], [durationFrames],
  /// [startFrame] (default `0`), and [parent] (default `null`).
  const FixedTimeScope({
    required this.fps,
    required this.durationFrames,
    this.startFrame = 0,
    this.parent,
  });

  @override
  final int fps;

  @override
  final int durationFrames;

  @override
  final int startFrame;

  @override
  final TimeScope? parent;
}
