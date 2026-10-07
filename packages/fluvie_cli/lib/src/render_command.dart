import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/capture_process.dart' show resolveProjectDir;
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_defines.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:path/path.dart' as p;

/// Creates the per-render temp sandbox; deleted after the render unless
/// `--keep-temp` is passed.
// coverage:ignore-line filesystem glue makes a real temp dir banned in unit tests
Future<Directory> createRenderSandbox() => Directory.systemTemp.createTemp('fluvie_render_');

/// `fluvie render <key> --out <file>` (or `--spec <file.fluvie.json>`): capture
/// the composition with `flutter test`, then encode the sandbox with ffmpeg per
/// the manifest.
///
/// The two-process protocol: the harness writes `frames.rgba` and a final
/// `manifest.json` (the completion signal + complete encode argument array)
/// into a CLI-created sandbox; the CLI validates the manifest and spawns
/// ffmpeg with exactly those arguments. With `--spec`, the harness builds the
/// composition from a serialized `VideoSpec` document instead of a registry key.
final class RenderCommand {
  /// Creates the command; `runner` and `createSandbox` are injectable for
  /// tests.
  RenderCommand({
    this._runner = const IoProcessRunner(),
    this._createSandbox = createRenderSandbox,
    this._resolveFfmpeg = ensureFfmpeg,
  });

  final ProcessRunner _runner;
  final Future<Directory> Function() _createSandbox;
  final FfmpegResolver _resolveFfmpeg;

  /// The `render` command's argument parser.
  static ArgParser buildParser() {
    final parser = ArgParser(usageLineLength: 80)
      ..addOption('out', help: 'Output path (default: build/fluvie/<composition>.mp4).')
      ..addOption('spec', help: 'Render a VideoSpec JSON file instead of a registry key.')
      ..addOption(
        'entry',
        defaultsTo: 'build',
        help: 'The top-level function returning the Video, when rendering a .dart file.',
      )
      ..addFlag(
        'cache',
        negatable: false,
        hide: true,
        help: 'Compatibility alias: local content caches are enabled by default.',
      );
    addSharedRenderOptions(parser);
    return parser;
  }

  /// Runs the command for parsed [args]; returns the process exit code
  /// (`0` ok, `64` usage, `1` operational failure).
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    final specPath = args.option('spec');
    final hasSpec = specPath != null && specPath.isNotEmpty;
    final String key;
    if (hasSpec) {
      if (args.rest.isNotEmpty) {
        err.writeln('render takes a composition key OR --spec, not both.');
        return 64;
      }
      key = '';
    } else {
      if (args.rest.length != 1) {
        err.writeln('render needs exactly one composition key.\n\n${buildParser().usage}');
        return 64;
      }
      key = args.rest.single;
    }
    final int? frames;
    final ExportFlags flags;
    try {
      frames = validateFrames(args.option('frames'));
      flags = validateExportFlags(args);
      validateRenderAdapters(args);
    } on UsageFailure catch (failure) {
      err.writeln(failure.message);
      return 64;
    }
    final extraDefines = hasSpec ? specDefines(specPath) : const <String, String>{};
    try {
      // A `.dart` positional is a composition file: it needs no registry and no
      // committed harness, so the CLI stages one that imports it directly.
      final target = !hasSpec && isFileTarget(key)
          ? resolveFileTarget(
              arg: key,
              entry: args.option('entry') ?? 'build',
              project: args.option('project'),
            )
          : null;
      final projectDir = target?.projectDir ?? resolveProjectDir(project: args.option('project'));
      final rendererPath = args.option('renderer');
      final renderer = rendererPath == null
          ? null
          : resolveFileTarget(
              arg: rendererPath,
              entry: args.option('renderer-entry') ?? 'buildRenderer',
              project: projectDir,
            );
      final requestedOut = args.option('out');
      final outPath = requestedOut == null || requestedOut.isEmpty
          ? defaultRenderOutput(projectDir, hasSpec ? specPath : key, format: flags.format)
          : requestedOut;
      return await captureThenEncode(
        runner: _runner,
        createSandbox: _createSandbox,
        args: args,
        // The composition key namespaces the frame cache; a file target has no
        // registry key, so its path stands in.
        key: target == null ? key : p.relative(target.path, from: target.projectDir),
        outPath: outPath,
        frames: frames,
        flags: flags,
        extraDefines: extraDefines,
        projectDirOverride: projectDir,
        // Full local source/resource hashes invalidate the managed frame cache.
        noCacheOverride: args.flag('no-cache'),
        stage: target == null
            ? null
            : (projectDir) => stageManagedHarness(
                projectDir: projectDir,
                runner: _runner,
                target: target,
                renderer: renderer,
              ),
        out: out,
        err: err,
        resolveFfmpeg: _resolveFfmpeg,
      );
    } on CliFailure catch (failure) {
      if (args.flag('machine')) rethrow;
      err.writeln(failure.message);
      return 1;
    }
  }
}
