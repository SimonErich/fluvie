import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_api/src/render/render_request.dart';
import 'package:fluvie_api/src/render/render_runner.dart';
import 'package:fluvie_cli/fluvie_cli.dart';

/// The production [RenderRunner]: it drives the `fluvie_cli` capture→encode
/// pipeline against a Flutter render project.
///
/// All process work goes through the injectable [ProcessRunner] seam, so the
/// mapping logic (defines, format, progress, output collection) is unit-tested
/// without a real Flutter/ffmpeg toolchain. AI authoring (`prompt`/`edit`) runs
/// inside the render project under `flutter test`, which inherits [aiEnv].
final class PipelineRenderRunner implements RenderRunner {
  /// Creates the runner. [renderProject] and [ffmpegPath] mirror the CLI's
  /// `--project`/`--ffmpeg`; [aiEnv] is forwarded to the capture process.
  PipelineRenderRunner({
    this.renderProject,
    this.ffmpegPath,
    this.aiEnv = const {},
    this.processRunner = const IoProcessRunner(),
    Future<Directory> Function()? createSandbox,
  }) : _createSandbox = createSandbox ?? _defaultSandbox;

  /// The Flutter project hosting the capture harness, or `null` to auto-discover.
  final String? renderProject;

  /// The ffmpeg binary, or `null` for `ffmpeg` on PATH.
  final String? ffmpegPath;

  /// AI provider/model/key env vars forwarded to the capture process.
  final Map<String, String> aiEnv;

  /// The process seam every spawn goes through (injected for tests).
  final ProcessRunner processRunner;

  final Future<Directory> Function() _createSandbox;

  static const _pollInterval = Duration(milliseconds: 100);

  @override
  Future<RenderOutcome> run(
    RenderRequest request, {
    required Directory workDir,
    void Function(RenderProgress)? onProgress,
  }) async {
    await workDir.create(recursive: true);
    final (ext, contentType) = _formatTarget(request.options.format);
    final outPath = '${workDir.path}/video.$ext';
    final specOut = '${workDir.path}/spec.fluvie.json';
    final extraDefines = _defines(request, workDir, specOut);
    final progressFile = '${workDir.path}/progress';

    Timer? poll;
    if (onProgress != null) {
      poll = Timer.periodic(_pollInterval, (_) => _emit(progressFile, onProgress));
    }
    final out = StringBuffer();
    final err = StringBuffer();
    try {
      final code = await runRenderPipeline(
        runner: processRunner,
        createSandbox: _createSandbox,
        options: (
          ffmpegBinary: ffmpegPath,
          projectDir: renderProject,
          noCache: false,
          // The server never auto-downloads mid-request; its image provisions
          // a pinned FFmpeg ahead of time (or FFMPEG_PATH points at one).
          noDownload: true,
          // Server renders use the default tester backend, not Impeller.
          enableImpeller: false,
          verbose: true,
          keepTemp: false,
        ),
        key: request is KeyRenderRequest ? request.key : '',
        outPath: outPath,
        frames: null,
        flags: (
          aspect: request.options.aspect,
          quality: request.options.quality,
          format: request.options.format,
          poster: request.options.poster,
        ),
        extraDefines: extraDefines,
        environment: {if (onProgress != null) 'FLUVIE_PROGRESS_FILE': progressFile, ...aiEnv},
        out: out,
        err: err,
      );
      if (code != 0) throw RenderFailure('Render exited with code $code');
    } on CliFailure catch (failure) {
      throw RenderFailure(failure.message);
    } finally {
      poll?.cancel();
      if (onProgress != null) _emit(progressFile, onProgress);
    }

    if (!File(outPath).existsSync()) {
      throw const RenderFailure('Render produced no output file');
    }
    final poster = File(_posterPath(outPath));
    final spec = File(specOut);
    final keepsSpec = request is PromptRenderRequest || request is EditRenderRequest;
    return RenderOutcome(
      videoPath: outPath,
      videoContentType: contentType,
      posterPath: poster.existsSync() ? poster.path : null,
      specPath: keepsSpec && spec.existsSync() ? spec.path : null,
    );
  }

  Map<String, String> _defines(RenderRequest request, Directory workDir, String specOut) =>
      switch (request) {
        KeyRenderRequest() => const {},
        SpecRenderRequest(:final spec) => specDefines(
          _writeJson(spec, '${workDir.path}/input.fluvie.json'),
        ),
        PromptRenderRequest(:final prompt, :final provider) => generateDefines(
          prompt: prompt,
          specOut: specOut,
          provider: provider,
        ),
        EditRenderRequest(:final baseSpec, :final change, :final provider) => editDefines(
          baseSpecPath: _writeJson(baseSpec, '${workDir.path}/base.fluvie.json'),
          change: change,
          specOut: specOut,
          provider: provider,
        ),
      };

  String _writeJson(Map<String, Object?> json, String path) {
    File(path).writeAsStringSync(jsonEncode(json));
    return path;
  }

  void _emit(String progressFile, void Function(RenderProgress) onProgress) {
    final file = File(progressFile);
    if (!file.existsSync()) return;
    final progress = parseRenderProgress(file.readAsStringSync());
    if (progress != null) onProgress(progress);
  }

  static (String, String) _formatTarget(String? format) => switch (format) {
    null || 'mp4' => ('mp4', 'video/mp4'),
    'gif' => ('gif', 'image/gif'),
    'transparent' => ('webm', 'video/webm'),
    // coverage:ignore-line: unreachable; formats are validated at request parse
    _ => throw RenderFailure('Unsupported format: $format'),
  };

  static String _posterPath(String outPath) =>
      outPath.replaceFirst(RegExp(r'\.[^.]+$'), '.poster.png');

  // coverage:ignore-start: makes a real temp dir; the unit tests inject their own
  static Future<Directory> _defaultSandbox() => Directory.systemTemp.createTemp('fluvie_api_cap_');
  // coverage:ignore-end
}
