import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_defines.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';

/// Creates the per-render temp sandbox; deleted after the render unless
/// `--keep-temp` is passed.
// coverage:ignore-line: filesystem glue; makes a real temp dir, banned in unit tests
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
      ..addOption('out', help: 'Path of the output file (required).')
      ..addOption('spec', help: 'Render a VideoSpec JSON file instead of a registry key.');
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
    final outPath = args.option('out');
    if (outPath == null || outPath.isEmpty) {
      err.writeln('render needs --out <file>.\n\n${buildParser().usage}');
      return 64;
    }
    final int? frames;
    final ExportFlags flags;
    try {
      frames = validateFrames(args.option('frames'));
      flags = validateExportFlags(args);
    } on UsageFailure catch (failure) {
      err.writeln(failure.message);
      return 64;
    }
    final extraDefines = hasSpec ? specDefines(specPath) : const <String, String>{};
    try {
      return await captureThenEncode(
        runner: _runner,
        createSandbox: _createSandbox,
        args: args,
        key: key,
        outPath: outPath,
        frames: frames,
        flags: flags,
        extraDefines: extraDefines,
        out: out,
        err: err,
        resolveFfmpeg: _resolveFfmpeg,
      );
    } on CliFailure catch (failure) {
      err.writeln(failure.message);
      return 1;
    }
  }
}
