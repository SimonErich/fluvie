import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:fluvie_server/src/api/render/code_render_setup.dart';
import 'package:fluvie_server/src/api/render/render_code_printer.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';

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
    this.captureTimeout = const Duration(minutes: 8),
    Future<Directory> Function()? createSandbox,
  }) : _createSandbox = createSandbox ?? _defaultSandbox;

  /// The Flutter project hosting the capture harness, or `null` to auto-discover.
  final String? renderProject;

  /// The wall-clock ceiling on a code render's capture. A runaway untrusted
  /// `build()` (an infinite loop) is abandoned and surfaced as a [RenderFailure]
  /// rather than hanging the worker. Applied to code renders only — trusted
  /// key/spec/AI renders keep their existing unbounded behavior.
  final Duration captureTimeout;

  /// The ffmpeg binary, or `null` for `ffmpeg` on PATH.
  final String? ffmpegPath;

  /// AI provider/model/key env vars forwarded to the capture process.
  final Map<String, String> aiEnv;

  /// The process seam every spawn goes through (injected for tests).
  final ProcessRunner processRunner;

  final Future<Directory> Function() _createSandbox;

  static const _pollInterval = Duration(milliseconds: 100);
  static const _defaultHarnessPath = 'test/render/capture_harness_test.dart';

  @override
  Future<RenderOutcome> run(
    RenderRequest request, {
    required Directory workDir,
    void Function(RenderProgress)? onProgress,
    void Function(String code, Map<String, Object?> spec)? onAuthored,
  }) async {
    await workDir.create(recursive: true);
    final (ext, contentType) = _formatTarget(request.options.format);
    final outPath = '${workDir.path}/video.$ext';
    final specOut = '${workDir.path}/spec.fluvie.json';
    final progressFile = '${workDir.path}/progress';
    final isAiRender = request is PromptRenderRequest || request is EditRenderRequest;
    // A code render stages an isolated, per-render harness under the project and
    // runs flutter test against it, forwarding NO aiEnv (the untrusted snippet
    // must never see the AI keys). Every other request drives the permanent
    // harness with --dart-define authoring and inherits aiEnv.
    // note: a content-hash cache (fnv1a of the normalized code) could let an
    // identical resubmission reuse a prior output, but the queue keys outputs by
    // job id and deletes the work dir per job, so a cross-job result cache is a
    // separate change — deliberately skipped here to keep the job model simple.
    final isCode = request is CodeRenderRequest;
    final staging = isCode
        ? stageCodeRenderOrFail(renderProject: renderProject, code: request.code)
        : null;
    final environment = {
      if (onProgress != null) 'FLUVIE_PROGRESS_FILE': progressFile,
      if (!isCode) ...aiEnv,
    };

    Timer? poll;
    if (onProgress != null) {
      poll = Timer.periodic(_pollInterval, (_) => _emit(progressFile, onProgress));
    }
    // For an AI render, the harness writes the authored spec during capture
    // (before the encode finishes); the watcher surfaces the printed code and
    // the decoded spec early, together.
    final codeWatcher = isAiRender
        ? SpecCodeWatcher(specPath: specOut, interval: _pollInterval, onAuthored: onAuthored)
        : null;
    final out = StringBuffer();
    final err = StringBuffer();
    try {
      final code = await _bounded(
        runRenderPipeline(
          runner: processRunner,
          createSandbox: _createSandbox,
          options: (
            ffmpegBinary: ffmpegPath,
            projectDir: staging?.projectDir ?? renderProject,
            // The shared frame cache keys on the composition key (always "code"
            // for the Playground) and NOT the snippet, so it would serve one
            // submission's frames for another. Disable it for code renders.
            noCache: isCode,
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
          harnessPath: staging?.harnessPath ?? _defaultHarnessPath,
          // Every render fed by an untrusted submission — a snippet, a posted
          // spec, or an AI-authored spec — blocks FileSource so it cannot read
          // the worker's filesystem. Only a trusted key render (a bundled,
          // developer-authored lesson) reads local files normally. The block
          // merges over each request's own defines (empty for a code render,
          // which takes the staged path).
          extraDefines: {
            ..._defines(request, workDir, specOut),
            if (request is! KeyRenderRequest) 'FLUVIE_BLOCK_FILE_SOURCES': 'true',
          },
          environment: environment,
          out: out,
          err: err,
        ),
        bounded: isCode,
      );
      if (code != 0) throw RenderFailure('Render exited with code $code');
    } on CliFailure catch (failure) {
      throw RenderFailure(failure.message);
    } finally {
      staging?.cleanup();
      poll?.cancel();
      // Print the spec one last time if the poll never caught it (a fast render).
      codeWatcher?.flush();
      if (onProgress != null) _emit(progressFile, onProgress);
    }

    if (!File(outPath).existsSync()) {
      throw const RenderFailure('Render produced no output file');
    }
    final poster = File(_posterPath(outPath));
    final specFile = File(specOut);
    return RenderOutcome(
      videoPath: outPath,
      videoContentType: contentType,
      posterPath: poster.existsSync() ? poster.path : null,
      specPath: isAiRender && specFile.existsSync() ? specFile.path : null,
      code: codeWatcher?.code,
      spec: codeWatcher?.spec,
    );
  }

  // Bounds [pipeline] by the wall clock for a code render so a runaway untrusted
  // build() is abandoned (the orphaned flutter-test process is reaped by the OS/
  // container) and surfaced as a failure, not a hung worker.
  Future<int> _bounded(Future<int> pipeline, {required bool bounded}) => bounded
      ? pipeline.timeout(
          captureTimeout,
          onTimeout: () =>
              throw RenderFailure('Render timed out after ${captureTimeout.inSeconds}s'),
        )
      : pipeline;

  Map<String, String> _defines(RenderRequest request, Directory workDir, String specOut) =>
      switch (request) {
        // A code render carries no defines of its own; the block below is
        // merged in and the staged harness supplies the rest.
        CodeRenderRequest() => const {},
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
    // coverage:ignore-line unreachable formats are validated at request parse
    _ => throw RenderFailure('Unsupported format: $format'),
  };

  static String _posterPath(String outPath) =>
      outPath.replaceFirst(RegExp(r'\.[^.]+$'), '.poster.png');

  // coverage:ignore-start makes a real temp dir the unit tests inject their own
  static Future<Directory> _defaultSandbox() =>
      Directory.systemTemp.createTemp('fluvie_server_cap_');
  // coverage:ignore-end
}
