import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Resolves an element's alive-[window] to absolute video frames within
/// [sceneScope].
///
/// A `null` window means the element is alive for the whole scene. An explicit
/// window is scene-relative: its endpoints
/// resolve against [sceneScope], clamp into the scene's own span (an element
/// can never overhang its scene; a window lying entirely outside collapses to
/// zero length at the nearest scene edge), and shift by the scene's absolute
/// start frame. Throws an [ArgumentError] when the window is inverted, like
/// [TimeRange.resolveFrames].
({int start, int end}) resolveElementWindow(TimeRange? window, TimeScopeData sceneScope) {
  if (window == null) {
    return (start: sceneScope.startFrame, end: sceneScope.endFrame);
  }
  final clamped = window.resolveClamped(sceneScope, min: 0, max: sceneScope.durationFrames);
  return (
    start: sceneScope.startFrame + clamped.start,
    end: sceneScope.startFrame + clamped.end,
  );
}

/// The nearest scope for an element: a child scope spanning its resolved
/// [window], or [sceneScope] itself when there is no window.
///
/// This is what makes `0.5.relative` mean "half of my own window" on a
/// windowed element and "half of the scene" on a bare one.
TimeScopeData elementScopeFor(TimeRange? window, TimeScopeData sceneScope) {
  if (window == null) return sceneScope;
  final resolved = resolveElementWindow(window, sceneScope);
  return sceneScope.child(
    startFrame: resolved.start,
    durationFrames: resolved.end - resolved.start,
  );
}
