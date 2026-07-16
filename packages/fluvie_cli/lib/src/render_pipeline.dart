import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/capture_process.dart';
import 'package:fluvie_cli/src/encode_process.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart' show ProvisionLog;
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/stage_harness.dart';

/// Adds the options shared by `render`, `generate`, and `edit` to [parser].
void addSharedRenderOptions(ArgParser parser) => parser
  ..addOption(
    'project',
    help:
        'Flutter project containing the capture harness '
        '(default: the auto-discovered "example" project).',
  )
  ..addOption('ffmpeg', help: 'Path of the ffmpeg binary (default: ffmpeg on PATH).')
  ..addOption('frames', help: 'Capture only the first N frames (draft renders).')
  ..addOption('aspect', help: 'Aspect ratio: ${aspectNames.join(', ')}.')
  ..addOption('quality', help: 'Encode quality: ${qualityNames.join(', ')}.')
  ..addOption('format', help: 'Export format: ${formatNames.join(', ')}.')
  ..addOption('poster', help: 'Poster thumbnail Time (e.g. "1.5s", "30f", "500ms").')
  ..addFlag('no-cache', negatable: false, help: 'Bypass the frame cache for this render.')
  ..addFlag(
    'no-download',
    negatable: false,
    help: 'Never auto-download FFmpeg; fail if none is found (see `fluvie ffmpeg install`).',
  )
  ..addFlag(
    'enable-impeller',
    negatable: false,
    help: 'Capture with Impeller (passes --enable-impeller to flutter test).',
  )
  ..addFlag('keep-temp', negatable: false, help: 'Keep the render sandbox for inspection.')
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
  StagedHarness Function(String projectDir)? stage,
  Map<String, String>? environment,
  void Function(StringSink out) report = _noReport,
  FfmpegResolver resolveFfmpeg = ensureFfmpeg,
}) async {
  // Resolve (and, if needed and allowed, download) ffmpeg BEFORE the slow
  // capture step. The resolved binary — explicit, cached, on PATH, or freshly
  // provisioned — is what the encode then runs.
  final ffmpeg = await resolveFfmpeg(
    runner,
    binary: options.ffmpegBinary,
    allowDownload: !options.noDownload,
    log: out.writeln,
  );
  final projectDir = resolveProjectDir(project: options.projectDir);
  final staged = stage?.call(projectDir);
  final sandbox = await createSandbox();
  try {
    await runCapture(
      runner: runner,
      projectDir: projectDir,
      key: key,
      sandbox: sandbox,
      frames: frames,
      noCache: options.noCache,
      impeller: options.enableImpeller,
      verbose: options.verbose,
      aspect: flags.aspect,
      quality: flags.quality,
      format: flags.format,
      poster: flags.poster,
      harnessPath: staged?.harnessPath ?? harnessPath,
      extraDefines: extraDefines,
      // The capture extracts a clip's frames itself, in the test subprocess, so
      // it needs the gate-resolved ffmpeg on PATH too — not just the encode,
      // which the CLI spawns directly. Without this a downloaded (cache-only)
      // ffmpeg encodes fine while every Clip fails to decode.
      environment: _withFfmpegOnPath(environment, ffmpeg),
      err: err,
    );
    final output = await runEncode(
      runner: runner,
      sandbox: sandbox,
      outPath: outPath,
      ffmpegBinary: ffmpeg,
    );
    out.writeln('Wrote ${output.path}');
    report(out);
    return 0;
  } finally {
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
  StagedHarness Function(String projectDir)? stage,
  void Function(StringSink out) report = _noReport,
  FfmpegResolver resolveFfmpeg = ensureFfmpeg,
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
  extraDefines: extraDefines,
  stage: stage,
  out: out,
  err: err,
  report: report,
  resolveFfmpeg: resolveFfmpeg,
);

void _noReport(StringSink out) {}
