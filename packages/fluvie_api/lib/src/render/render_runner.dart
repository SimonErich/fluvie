import 'dart:io';

import 'package:fluvie_api/src/render/render_request.dart';
import 'package:fluvie_cli/fluvie_cli.dart' show RenderProgress;
import 'package:meta/meta.dart';

/// What a finished render produced on disk, ready to hand to the file store.
@immutable
final class RenderOutcome {
  /// Creates an outcome.
  const RenderOutcome({
    required this.videoPath,
    required this.videoContentType,
    this.posterPath,
    this.specPath,
  });

  /// Absolute path of the rendered video.
  final String videoPath;

  /// The video's MIME type (e.g. `video/mp4`).
  final String videoContentType;

  /// Absolute path of the poster PNG, or `null` when none was requested.
  final String? posterPath;

  /// Absolute path of the authored spec JSON (prompt/edit), or `null`.
  final String? specPath;
}

/// Runs one render to completion, writing its outputs under a working directory.
///
/// The real implementation drives the `fluvie_cli` capture→encode pipeline; the
/// fake scripts outputs for tests. A failure is a [RenderFailure].
// ignore: one_member_abstracts
abstract interface class RenderRunner {
  /// Renders [request] into [workDir], reporting live frame [onProgress], and
  /// returns the produced paths. Throws [RenderFailure] on any failure.
  Future<RenderOutcome> run(
    RenderRequest request, {
    required Directory workDir,
    void Function(RenderProgress)? onProgress,
  });
}

/// Thrown when a render fails (a bad spec, a capture/encode error, a missing
/// toolchain). The message is client-safe (no secrets, no full stack).
final class RenderFailure implements Exception {
  /// Creates the failure with a [message].
  const RenderFailure(this.message);

  /// What went wrong, surfaced as the failed job's error.
  final String message;

  @override
  String toString() => 'RenderFailure: $message';
}
