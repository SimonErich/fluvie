import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show RenderProgress;
import 'package:fluvie_server/src/api/render/render_request.dart';
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
    this.code,
    this.spec,
  });

  /// Absolute path of the rendered video.
  final String videoPath;

  /// The video's MIME type (e.g. `video/mp4`).
  final String videoContentType;

  /// Absolute path of the poster PNG, or `null` when none was requested.
  final String? posterPath;

  /// Absolute path of the authored spec JSON (prompt/edit), or `null`.
  final String? specPath;

  /// The printed Dart `Video build()` snippet for an AI (prompt/edit) render,
  /// or `null` for other kinds and when the authored spec could not be printed.
  final String? code;

  /// The decoded authored `VideoSpec` for an AI (prompt/edit) render, or `null`
  /// for other kinds and when the authored spec could not be read. Set at the
  /// same moment as [code]; the client hands it back as the `base` of an edit.
  final Map<String, Object?>? spec;
}

/// Runs one render to completion, writing its outputs under a working directory.
///
/// The real implementation drives the `fluvie_cli` capture→encode pipeline; the
/// fake scripts outputs for tests. A failure is a [RenderFailure].
// ignore: one_member_abstracts — the seam is the type; a scripted fake backs it in tests.
abstract interface class RenderRunner {
  /// Renders [request] into [workDir], reporting live frame [onProgress], and
  /// returns the produced paths. Throws [RenderFailure] on any failure.
  ///
  /// [onAuthored] fires once with the printed Dart snippet and the decoded spec
  /// as soon as an AI (prompt/edit) render's authored spec is available,
  /// typically before the video finishes, so a polling client can show the code
  /// (and reuse the spec) first. It never fires for other render kinds or when
  /// the spec cannot be printed.
  Future<RenderOutcome> run(
    RenderRequest request, {
    required Directory workDir,
    void Function(RenderProgress)? onProgress,
    void Function(String code, Map<String, Object?> spec)? onAuthored,
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
