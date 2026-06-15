/// @docImport 'package:fluvie/src/core/time.dart';
library;

import 'package:fluvie/src/core/time_scope.dart';
import 'package:meta/meta.dart';

/// The engine's concrete [TimeScope]: an immutable value pinning down the
/// fps, absolute position, and length of one window in the video.
///
/// Scopes chain root → scene → element window via [child]; every level keeps
/// the same fps and links back through [parent]. A [Time] resolves against
/// the *nearest* scope, which is why `0.5.relative` means "half of my own
/// window" wherever it is written.
///
/// Pure data with value equality (including the parent chain) — two builds of
/// the same composition produce equal scopes, which keeps timing resolution
/// deterministic and cache-friendly.
@immutable
final class TimeScopeData implements TimeScope {
  /// Creates a scope spanning [durationFrames] frames from absolute video
  /// frame [startFrame], at [fps]; [parent] is `null` at the root.
  const TimeScopeData({
    required this.fps,
    required this.startFrame,
    required this.durationFrames,
    this.parent,
  });

  @override
  final int fps;

  @override
  final int startFrame;

  @override
  final int durationFrames;

  @override
  final TimeScopeData? parent;

  /// The first absolute video frame *after* this window:
  /// `startFrame + durationFrames`.
  int get endFrame => startFrame + durationFrames;

  /// A nested scope inside this one — same [fps], `parent: this`.
  ///
  /// [startFrame] is absolute (video frames), exactly like this scope's own.
  TimeScopeData child({required int startFrame, required int durationFrames}) => TimeScopeData(
    fps: fps,
    startFrame: startFrame,
    durationFrames: durationFrames,
    parent: this,
  );

  @override
  bool operator ==(Object other) =>
      other is TimeScopeData &&
      other.fps == fps &&
      other.startFrame == startFrame &&
      other.durationFrames == durationFrames &&
      other.parent == parent;

  @override
  int get hashCode => Object.hash(TimeScopeData, fps, startFrame, durationFrames, parent);

  @override
  String toString() {
    final span = 'fps: $fps, frames: $startFrame..$endFrame';
    return parent == null ? 'TimeScopeData($span)' : 'TimeScopeData($span, parent: $parent)';
  }
}
