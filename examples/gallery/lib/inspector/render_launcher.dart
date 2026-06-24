import 'package:flutter/foundation.dart';

/// What one render produced: the process exit code plus everything it wrote to
/// stdout and stderr, and (for the API backend) where the file can be
/// downloaded.
final class RenderLaunchResult {
  /// Creates a result; streams may be empty, never null.
  const RenderLaunchResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.downloadUrl,
  });

  /// The render outcome code (`0` = the video was produced).
  final int exitCode;

  /// Everything the render wrote to stdout.
  final String stdout;

  /// Everything the render wrote to stderr.
  final String stderr;

  /// Where the rendered file can be downloaded, for the API backend; `null` for
  /// the local backend (which writes `build/<key>.mp4` on disk).
  final String? downloadUrl;
}

/// How far a render has progressed: [completed] of [total] frames captured.
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
}

/// Launches one render of a registered composition key.
///
/// Abstract so view-model tests inject a mocktail fake, and so the example can
/// swap a local desktop backend (`ProcessRenderLauncher`) for a server backend
/// (`ApiRenderLauncher`) without the UI knowing which is in play.
// ignore: one_member_abstracts
abstract interface class RenderLauncher {
  /// Renders the composition registered under [key] and completes with the
  /// outcome.
  ///
  /// [onProgress] is called repeatedly while the render runs with the live
  /// frame count, so a UI can show a progress bar that updates in real time.
  Future<RenderLaunchResult> render(String key, {void Function(RenderProgress)? onProgress});
}
