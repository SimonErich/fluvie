import 'package:fluvie/src/core/render_phase.dart';

/// A progress update from a render: the current [phase], optional frame counts
/// while capturing, and the [compositionKey] so concurrent renders stay
/// distinguishable in logs.
///
/// One callback shape serves both on-device renderers: web reports per-frame
/// capture counts; mobile reports them too when its capture loop surfaces them,
/// and leaves [completedFrames]/[totalFrames] null otherwise.
class RenderProgress {
  /// Creates a progress update for [phase].
  const RenderProgress(
    this.phase, {
    this.completedFrames,
    this.totalFrames,
    this.compositionKey,
  });

  /// The stage the render is in.
  final RenderPhase phase;

  /// Frames captured so far during [RenderPhase.capturing], or null.
  final int? completedFrames;

  /// Total frames to capture, or null when not yet known or not capturing.
  final int? totalFrames;

  /// The key of the render this update belongs to, or null.
  final String? compositionKey;

  @override
  String toString() =>
      'RenderProgress(${phase.name}, ${completedFrames ?? '-'}/${totalFrames ?? '-'}'
      '${compositionKey == null ? '' : ', key: $compositionKey'})';
}

/// A sink for [RenderProgress] updates, passed to a renderer's `render(...)`.
typedef RenderProgressCallback = void Function(RenderProgress progress);
