import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show RenderProgress;
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';

/// A scripted [RenderRunner] for queue and handler tests: it records each call,
/// emits the given [progress], then either writes stub outputs and returns or
/// throws [error].
final class FakeRenderRunner implements RenderRunner {
  /// Creates the fake.
  FakeRenderRunner({
    this.error,
    this.progress = const [RenderProgress(completed: 1, total: 1)],
    this.writePoster = true,
    this.code,
    this.spec,
  });

  /// The requests this runner was asked to render, in order.
  final List<RenderRequest> calls = [];

  /// A failure to throw instead of producing output, or `null` to succeed.
  final RenderFailure? error;

  /// Progress snapshots emitted before completing.
  final List<RenderProgress> progress;

  /// Whether to write a stub poster.
  final bool writePoster;

  /// Printed Dart code to surface (via `onAuthored` and the outcome), or `null`.
  final String? code;

  /// The decoded authored spec to surface alongside [code], or `null`.
  final Map<String, Object?>? spec;

  @override
  Future<RenderOutcome> run(
    RenderRequest request, {
    required Directory workDir,
    void Function(RenderProgress)? onProgress,
    void Function(String code, Map<String, Object?> spec)? onAuthored,
  }) async {
    calls.add(request);
    if (onProgress != null) progress.forEach(onProgress);
    if (code != null) onAuthored?.call(code!, spec ?? const {});
    if (error != null) throw error!;
    await workDir.create(recursive: true);
    final video = File('${workDir.path}/video.mp4')..writeAsBytesSync(const [0, 0, 0, 1]);
    String? poster;
    if (writePoster) {
      poster = '${workDir.path}/video.poster.png';
      File(poster).writeAsBytesSync(const [1, 2, 3]);
    }
    return RenderOutcome(
      videoPath: video.path,
      videoContentType: 'video/mp4',
      posterPath: poster,
      code: code,
      spec: spec,
    );
  }
}
