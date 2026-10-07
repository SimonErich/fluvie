import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/asset_catalog.dart';
import 'package:fluvie_cli/src/asset_inventory.dart';
import 'package:fluvie_cli/src/authoring_context.dart';
import 'package:fluvie_cli/src/capture_process.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/composition_fingerprint.dart';
import 'package:fluvie_cli/src/encode_process.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart' show ProvisionLog;
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/image_evidence.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_progress.dart';
import 'package:fluvie_cli/src/render_receipt.dart';
import 'package:fluvie_cli/src/stage_harness.dart';
import 'package:path/path.dart' as p;

/// Adds the options shared by `render`, `generate`, and `edit` to [parser].
void addSharedRenderOptions(ArgParser parser) => parser
  ..addOption(
    'project',
    help: 'Source Flutter project (default: discovered from the composition or current directory).',
  )
  ..addOption('ffmpeg', help: 'Explicit FFmpeg executable (default: managed pinned pair).')
  ..addOption('ffprobe', help: 'Path of the companion ffprobe binary.')
  ..addOption(
    'toolchain',
    defaultsTo: 'managed',
    allowed: ['managed', 'system'],
    help: 'Use the managed pinned toolchain or explicitly use system binaries.',
  )
  ..addOption('renderer', help: 'Dart file exposing a custom renderer factory.')
  ..addOption(
    'renderer-entry',
    defaultsTo: 'buildRenderer',
    help: 'Custom renderer factory function.',
  )
  ..addOption(
    'harness',
    help: 'Advanced: use this Flutter test harness instead of the managed adapter.',
  )
  ..addOption('frames', help: 'Capture only the first N frames (draft renders).')
  ..addOption('aspect', help: 'Aspect ratio: ${aspectNames.join(', ')}.')
  ..addOption('quality', help: 'Encode quality: ${qualityNames.join(', ')}.')
  ..addOption('format', help: 'Export format: ${formatNames.join(', ')}.')
  ..addOption('poster', help: 'Poster thumbnail Time (e.g. "1.5s", "30f", "500ms").')
  ..addFlag('no-cache', negatable: false, help: 'Bypass the frame cache for this render.')
  ..addOption(
    'cache-key',
    help: 'Identity/version of external runtime inputs; change it when inputs change.',
  )
  ..addFlag(
    'no-download',
    negatable: false,
    help: 'Use only a warmed managed cache or explicit/system FFmpeg and FFprobe pair.',
  )
  ..addFlag(
    'enable-impeller',
    negatable: false,
    help: 'Capture with Impeller (passes --enable-impeller to flutter test).',
  )
  ..addFlag('keep-temp', negatable: false, help: 'Keep the render sandbox for inspection.')
  ..addFlag('machine', negatable: false, help: 'Emit progress and final artifact as JSON lines.')
  ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Forward capture/encode output.');

/// Validates the export flags up front, mapping a bad enum to a [UsageFailure]
/// (exit 64) that names the valid set.
ExportFlags validateExportFlags(ArgResults args) => (
  aspect: validateEnumFlag(args.option('aspect'), flag: '--aspect', allowed: aspectNames),
  quality: validateEnumFlag(args.option('quality'), flag: '--quality', allowed: qualityNames),
  format: validateEnumFlag(args.option('format'), flag: '--format', allowed: formatNames),
  poster: validatePoster(args.option('poster'), flag: '--poster'),
);

/// Parses `--frames`, throwing a [UsageFailure] for a non-positive value.
int? validateFrames(String? framesOption) {
  if (framesOption == null) return null;
  final frames = int.tryParse(framesOption);
  if (frames == null || frames <= 0) {
    throw UsageFailure('--frames needs a positive integer, got "$framesOption".');
  }
  return frames;
}

/// The pipeline knobs that came from `--ffmpeg`/`--project`/`--no-cache`/
/// `--no-download`/`--enable-impeller`/`--verbose`/`--keep-temp`, decoupled from
/// [ArgResults] so a caller that has no command line (the render server) can
/// drive [runRenderPipeline] directly.
typedef RenderPipelineOptions = ({
  String? ffmpegBinary,
  String? projectDir,
  bool noCache,
  bool noDownload,
  bool enableImpeller,
  bool verbose,
  bool keepTemp,
});

/// Resolves the FFmpeg binary to use (the gate's [ensureFfmpeg] by default).
/// Injectable so command and pipeline tests stay hermetic — no real
/// environment, cache, or network.
typedef FfmpegResolver =
    Future<String> Function(
      ProcessRunner runner, {
      String? binary,
      bool allowDownload,
      ProvisionLog log,
    });

/// Pair resolver seam; legacy encoder-only injection remains supported.
typedef ToolchainResolver =
    Future<FfmpegToolchain> Function(
      ProcessRunner runner, {
      String? binary,
      String? probeBinary,
      String mode,
      bool allowDownload,
      ProvisionLog log,
    });

/// Validates mutually exclusive advanced host overrides.
void validateRenderAdapters(ArgResults args) {
  if (args.options.contains('image-evidence') &&
      args.flag('image-evidence') &&
      args.option('catalog') == null) {
    throw const UsageFailure('--image-evidence requires an explicitly selected --catalog.');
  }
  if (args.option('renderer') != null && args.option('harness') != null) {
    throw const UsageFailure('--renderer and --harness cannot be used together.');
  }
}

/// The shared capture→encode pipeline behind `render`, `generate`, and `edit`
/// (and the render server): the ffmpeg gate, a temp sandbox, the capture step
/// (with [extraDefines] and an optional per-run [environment]), the ffmpeg
/// encode, and sandbox cleanup. Returns the process exit code (`0` on success).
///
/// Throws a `CliFailure` on an operational failure; callers catch it and map it
/// to exit 1.
Future<int> runRenderPipeline({
  required ProcessRunner runner,
  required Future<Directory> Function() createSandbox,
  required RenderPipelineOptions options,
  required String key,
  required String outPath,
  required int? frames,
  required ExportFlags flags,
  required Map<String, String> extraDefines,
  required StringSink out,
  required StringSink err,
  String harnessPath = 'test/render/capture_harness_test.dart',
  FutureOr<StagedHarness> Function(String projectDir)? stage,
  Map<String, String>? environment,
  void Function(StringSink out) report = _noReport,
  FfmpegResolver resolveFfmpeg = ensureFfmpeg,
  ToolchainResolver? resolveToolchain,
  String? ffprobeBinary,
  String toolchainMode = 'managed',
  String? rendererPath,
  String rendererEntry = 'buildRenderer',
  String? harnessOverride,
  bool machine = false,
  String? authorContext,
  List<String> contextFiles = const [],
  String? authorAssetsDir,
  String? authorCatalogPath,
  bool imageEvidence = false,
  String? cacheKey,
  Future<void> Function(Directory sandbox, String fingerprint)? capture,
}) async {
  if (cacheKey != null &&
      (cacheKey.trim().isEmpty ||
          cacheKey.length > 4096 ||
          cacheKey.contains('\n') ||
          cacheKey.contains('\r'))) {
    throw const UsageFailure(
      '--cache-key needs a nonempty single-line identity of at most 4096 characters.',
    );
  }
  final authorOnly = extraDefines['FLUVIE_OPERATION'] == 'author';
  final projectDir = resolveProjectDir(project: options.projectDir);
  final author = extraDefines.containsKey('FLUVIE_AI_PROMPT');
  final assetsPath = resolveAuthoringInputPath(projectDir, authorAssetsDir ?? 'assets');
  final contextPaths = [
    for (final input in contextFiles) resolveAuthoringInputPath(projectDir, input),
  ];
  final catalogPath = authorCatalogPath == null
      ? null
      : resolveAuthoringInputPath(projectDir, authorCatalogPath);
  final evidenceImages = !imageEvidence
      ? <Map<String, Object?>>[]
      : await selectedImageEvidence(catalogPath!);
  final assets = Directory(assetsPath);
  final authorNeedsMedia =
      author && assets.existsSync() && inventoryFiles(assets).any(needsAssetProbe);
  // Resolve (and, if needed and allowed, download) ffmpeg BEFORE the slow
  // capture step. The resolved binary — explicit, cached, on PATH, or freshly
  // provisioned — is what the encode then runs.
  final FfmpegToolchain? toolchain;
  if ((!authorOnly || authorNeedsMedia) &&
      (resolveToolchain != null || resolveFfmpeg == ensureFfmpeg)) {
    toolchain = await (resolveToolchain ?? ensureFfmpegToolchain)(
      runner,
      binary: options.ffmpegBinary,
      probeBinary: ffprobeBinary,
      mode: toolchainMode,
      allowDownload: !options.noDownload,
      log: machine ? err.writeln : out.writeln,
    );
  } else {
    toolchain = null;
  }
  final ffmpeg = authorOnly
      ? ''
      : toolchain?.ffmpegPath ??
            await resolveFfmpeg(
              runner,
              binary: options.ffmpegBinary,
              allowDownload: !options.noDownload,
              log: machine ? err.writeln : out.writeln,
            );
  final spec = extraDefines.containsKey('FLUVIE_RENDER_SPEC');
  final renderer = rendererPath == null
      ? null
      : resolveFileTarget(arg: rendererPath, entry: rendererEntry, project: projectDir);
  final staged = harnessOverride != null
      ? null
      : stage != null
      ? await stage(projectDir)
      : spec || author
      ? await stageManagedHarness(
          projectDir: projectDir,
          runner: runner,
          spec: spec,
          author: author,
          renderer: renderer,
        )
      : null;
  final sourceFiles = staged?.sourceFiles ?? const <String>[];
  final sourceRoot = sourceFiles.isEmpty ? null : Directory(projectDir).resolveSymbolicLinksSync();
  final sourceCoverage = sourceFiles.every(
    (path) => p.isWithin(sourceRoot!, File(path).resolveSymbolicLinksSync()),
  );
  final cacheEnabled = !options.noCache && !author && (sourceCoverage || cacheKey != null);
  final generatedSources = [?staged?.dir.path, ...?staged?.generatedSourceDirectories];
  if (!options.noCache && !author && !sourceCoverage && cacheKey == null) {
    err.writeln(
      'Frame caching disabled: source files outside the selected project may import '
      'dependencies that its fingerprint does not cover. Use --cache-key to supply '
      'their revision, or keep caching disabled.',
    );
  }
  final renderOptions = <String, Object?>{
    'frames': frames,
    'aspect': flags.aspect,
    'quality': flags.quality,
    'format': flags.format,
    'poster': flags.poster,
    'impeller': options.enableImpeller,
    'renderer': rendererPath,
    'rendererEntry': rendererEntry,
    'harness': harnessOverride ?? staged?.harnessPath,
    'cacheEnabled': cacheEnabled,
    'cacheKey': ?cacheKey,
  };
  final fingerprintFiles = <String>[
    if (spec) extraDefines['FLUVIE_RENDER_SPEC']!,
    if (extraDefines['FLUVIE_AI_BASE_SPEC'] != null) extraDefines['FLUVIE_AI_BASE_SPEC']!,
    if (renderer != null) renderer.path,
    ?harnessOverride,
    if (staged != null) staged.harnessPath,
    ...?staged?.sourceFiles,
    if (staged != null && File(p.join(staged.dir.path, 'input.dart')).existsSync())
      p.join(staged.dir.path, 'input.dart'),
    ...contextPaths,
    ?catalogPath,
  ];
  final fingerprint = await fingerprintComposition(
    projectDir,
    context: {
      'options': renderOptions,
      'toolchain': toolchain?.toJson() ?? {'ffmpeg': ffmpeg},
    },
    extraFiles: fingerprintFiles,
    excludedSourceDirectories: generatedSources,
  );
  final sandbox = await createSandbox();
  void progress(String stage) {
    if (machine) out.writeln(jsonEncode({'schemaVersion': 1, 'event': 'progress', 'stage': stage}));
  }

  Timer? progressTimer;
  String? lastProgress;
  final progressPath = environment?['FLUVIE_PROGRESS_FILE'] ?? p.join(sandbox.path, 'progress.txt');
  void captureProgress() {
    final file = File(progressPath);
    if (!file.existsSync()) return;
    try {
      final value = file.readAsStringSync();
      if (value == lastProgress) return;
      final parsed = parseRenderProgress(value);
      if (parsed == null) return;
      lastProgress = value;
      out.writeln(
        jsonEncode({
          'schemaVersion': 1,
          'event': 'progress',
          'stage': 'capture',
          'completed': parsed.completed,
          'total': parsed.total,
          'fraction': parsed.fraction,
        }),
      );
    } on FileSystemException {
      /* A progress write may be in flight. */
    }
  }

  if (machine) {
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => captureProgress());
  }
  try {
    progress(authorOnly ? 'author' : 'capture');
    String? contextPath;
    if (author) {
      contextPath = p.join(sandbox.path, 'author-context.md');
      await File(contextPath).writeAsString(
        await buildAuthoringContext(
          projectDir: projectDir,
          toolchain: toolchain,
          context: authorContext,
          contextFiles: contextPaths,
          assetsDir: assetsPath,
          catalogPath: catalogPath,
        ),
      );
    }
    String? evidencePath;
    if (evidenceImages.isNotEmpty) {
      evidencePath = p.join(sandbox.path, 'image-evidence.json');
      final snapshots = <Map<String, Object?>>[];
      for (var index = 0; index < evidenceImages.length; index++) {
        final image = evidenceImages[index];
        final copied = await File(
          image['filePath']! as String,
        ).copy(p.join(sandbox.path, 'evidence_$index.png'));
        if (await assetContentHash(copied) != image['sha256']) {
          throw const CliFailure(
            'Image evidence changed during authoring preparation. Rebuild the catalog.',
          );
        }
        snapshots.add({...image, 'filePath': copied.path});
      }
      await File(evidencePath).writeAsString(jsonEncode(snapshots));
    }
    if (capture != null) {
      await capture(sandbox, fingerprint.digest);
    } else {
      await runCapture(
        runner: runner,
        projectDir: projectDir,
        key: key,
        sandbox: sandbox,
        frames: frames,
        noCache: !cacheEnabled,
        impeller: options.enableImpeller,
        verbose: options.verbose,
        aspect: flags.aspect,
        quality: flags.quality,
        format: flags.format,
        poster: flags.poster,
        harnessPath: harnessOverride == null
            ? staged?.harnessPath ?? harnessPath
            : p.absolute(harnessOverride),
        packageConfigPath: staged?.packageConfigPath,
        extraDefines: {
          ...extraDefines,
          'FLUVIE_PROJECT_DIR': p.absolute(projectDir),
          'FLUVIE_COMPOSITION_FINGERPRINT': fingerprint.digest,
          'FLUVIE_AI_CONTEXT_FILE': ?contextPath,
          'FLUVIE_AI_EVIDENCE_FILE': ?evidencePath,
          if (ffmpeg.isNotEmpty) 'FLUVIE_FFMPEG': ffmpeg,
          if (toolchain != null) 'FLUVIE_FFPROBE': toolchain.ffprobePath,
        },
        // The capture extracts a clip's frames itself, in the test subprocess, so
        // it needs the gate-resolved ffmpeg on PATH too — not just the encode,
        // which the CLI spawns directly. Without this a downloaded (cache-only)
        // ffmpeg encodes fine while every Clip fails to decode.
        environment: _withFfmpegOnPath(
          machine
              ? {
                  ...?environment,
                  ...?(toolchain?.environment),
                  'FLUVIE_PROGRESS_FILE': progressPath,
                }
              : toolchain == null
              ? environment
              : {...?environment, ...toolchain.environment},
          ffmpeg,
        ),
        err: err,
      );
    }
    if (machine) captureProgress();
    if (authorOnly) {
      final specOut = extraDefines['FLUVIE_RENDER_SPEC_OUT'];
      if (specOut == null || !File(specOut).existsSync()) {
        throw const CliFailure('Authoring completed without writing its VideoSpec.');
      }
      if (machine) {
        out.writeln(
          jsonEncode({'schemaVersion': 1, 'event': 'authored', 'specPath': p.absolute(specOut)}),
        );
      } else {
        report(out);
      }
      return 0;
    }
    final manifestFile = File(p.join(sandbox.path, 'manifest.json'));
    final capturedManifest = manifestFile.existsSync()
        ? jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>
        : null;
    final rendererResult = _encodedResult(sandbox);
    final encoded = rendererResult?.file;
    final intent = rendererResult?.outputIntent ?? capturedManifest?['outputIntent'];
    final manifest = capturedManifest == null && intent == null
        ? null
        : <String, Object?>{
            ...?capturedManifest,
            'outputIntent': ?intent,
          };
    progress(encoded == null ? 'encode' : 'finalize');
    final output = encoded == null
        ? await runEncode(
            runner: runner,
            sandbox: sandbox,
            outPath: outPath,
            ffmpegBinary: ffmpeg,
          )
        : await moveIntoPlace(encoded, outPath);
    final finalFingerprint = author && extraDefines['FLUVIE_RENDER_SPEC_OUT'] != null
        ? await fingerprintComposition(
            projectDir,
            context: {
              'options': renderOptions,
              'toolchain': toolchain?.toJson() ?? {'ffmpeg': ffmpeg},
            },
            extraFiles: [...fingerprintFiles, extraDefines['FLUVIE_RENDER_SPEC_OUT']!],
            excludedSourceDirectories: generatedSources,
          )
        : fingerprint;
    final operation = extraDefines['FLUVIE_OPERATION'] ?? 'render';
    if (operation == 'render') {
      progress('verify');
      final receipt = await writeRenderReceipt(
        outputPath: output.absolute.path,
        sourceFingerprint: finalFingerprint.digest,
        inputs: finalFingerprint.toJson(),
        toolchain: {
          ...?(toolchain?.toJson()),
          if (toolchain == null) 'ffmpeg': ffmpeg,
          if (toolchain == null) 'build': 'injected',
          'sdk': finalFingerprint.sdk,
        },
        options: renderOptions,
        captureManifest: manifest,
        ffprobeBinary: toolchain?.ffprobePath,
        ffmpegBinary: ffmpeg,
        runner: runner,
        posterPath: manifest?['posterFileName'] == null ? null : posterOutputPath(outPath),
        source: key.isEmpty ? extraDefines['FLUVIE_RENDER_SPEC'] : key,
      );
      if (machine) {
        out.writeln(jsonEncode(renderArtifactEvent(receipt)));
      }
    }
    if (!machine) {
      out.writeln('Wrote ${output.absolute.path}');
      report(out);
    }
    return 0;
  } finally {
    progressTimer?.cancel();
    staged?.cleanup();
    if (options.keepTemp) {
      err.writeln('Keeping render sandbox at ${sandbox.path}');
    } else if (sandbox.existsSync()) {
      await sandbox.delete(recursive: true);
    }
  }
}

/// [environment] with [ffmpeg]'s directory prepended to `PATH`, so the capture
/// subprocess resolves the same binary the gate did.
///
/// A bare `ffmpeg` (already on PATH) needs no entry, and prepending rather than
/// replacing keeps the rest of the user's PATH intact.
Map<String, String>? _withFfmpegOnPath(Map<String, String>? environment, String ffmpeg) {
  if (!ffmpeg.contains(Platform.pathSeparator)) return environment;
  final dir = File(ffmpeg).parent.path;
  final path = Platform.environment['PATH'] ?? '';
  return {
    ...?environment,
    'PATH': path.isEmpty ? dir : '$dir${Platform.isWindows ? ';' : ':'}$path',
  };
}

/// The [ArgResults]-driven adapter the CLI commands call: reads the pipeline
/// options off [args] and delegates to [runRenderPipeline].
Future<int> captureThenEncode({
  required ProcessRunner runner,
  required Future<Directory> Function() createSandbox,
  required ArgResults args,
  required String key,
  required String outPath,
  required int? frames,
  required ExportFlags flags,
  required Map<String, String> extraDefines,
  required StringSink out,
  required StringSink err,
  String? projectDirOverride,
  bool? noCacheOverride,
  FutureOr<StagedHarness> Function(String projectDir)? stage,
  void Function(StringSink out) report = _noReport,
  FfmpegResolver resolveFfmpeg = ensureFfmpeg,
  Map<String, String>? environment,
}) => runRenderPipeline(
  runner: runner,
  createSandbox: createSandbox,
  options: (
    ffmpegBinary: args.option('ffmpeg'),
    projectDir: projectDirOverride ?? args.option('project'),
    noCache: noCacheOverride ?? args.flag('no-cache'),
    noDownload: args.flag('no-download'),
    enableImpeller: args.flag('enable-impeller'),
    verbose: args.flag('verbose'),
    keepTemp: args.flag('keep-temp'),
  ),
  key: key,
  outPath: outPath,
  frames: frames,
  flags: flags,
  extraDefines: {
    ...extraDefines,
    if (args.options.contains('ai-trace') && args.option('ai-trace') != null)
      'FLUVIE_AI_TRACE_OUT':
          extraDefines['FLUVIE_AI_TRACE_OUT'] ?? p.absolute(args.option('ai-trace')!),
  },
  environment: environment,
  stage: stage,
  out: out,
  err: err,
  report: report,
  resolveFfmpeg: resolveFfmpeg,
  ffprobeBinary: args.option('ffprobe'),
  toolchainMode: args.option('toolchain') ?? 'managed',
  machine: args.flag('machine'),
  cacheKey: args.option('cache-key'),
  authorContext: args.options.contains('context') ? args.option('context') : null,
  contextFiles: args.options.contains('context-file') ? args.multiOption('context-file') : const [],
  authorAssetsDir: args.options.contains('assets') ? args.option('assets') : null,
  authorCatalogPath: args.options.contains('catalog') ? args.option('catalog') : null,
  imageEvidence: args.options.contains('image-evidence') && args.flag('image-evidence'),
  rendererPath: args.option('renderer'),
  rendererEntry: args.option('renderer-entry') ?? 'buildRenderer',
  harnessOverride: args.option('harness'),
);

({File file, Map<String, Object?>? outputIntent})? _encodedResult(Directory sandbox) {
  final receipt = File(p.join(sandbox.path, 'render-result.json'));
  if (!receipt.existsSync()) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(receipt.readAsStringSync());
  } on FormatException catch (error) {
    throw CliFailure('Invalid render-result.json: ${error.message}');
  }
  if (decoded is! Map<String, Object?> || decoded['schemaVersion'] != 1) {
    throw const CliFailure(
      'Unsupported render-result.json schema. Use matching CLI and Fluvie versions.',
    );
  }
  final kind = decoded['kind'];
  final path = decoded[kind == 'capture' ? 'manifestPath' : 'filePath'];
  if (path is! String ||
      !File(path).existsSync() ||
      !p.isWithin(sandbox.resolveSymbolicLinksSync(), File(path).resolveSymbolicLinksSync())) {
    throw const CliFailure(
      'The render result must name an existing file inside its output workspace.',
    );
  }
  if (kind == 'capture') {
    if (p.normalize(p.absolute(path)) !=
        p.normalize(p.join(sandbox.absolute.path, 'manifest.json'))) {
      throw const CliFailure('The capture result must use manifest.json in its output workspace.');
    }
    return null;
  }
  if (!['encoded', 'frame', 'inspect', 'audio', 'review'].contains(kind)) {
    throw CliFailure('Unknown render result kind "$kind".');
  }
  final intent = decoded['outputIntent'];
  if (intent != null && intent is! Map<String, Object?>) {
    throw const CliFailure('The render result outputIntent must be a JSON object.');
  }
  return (file: File(path), outputIntent: intent as Map<String, Object?>?);
}

void _noReport(StringSink out) {}
