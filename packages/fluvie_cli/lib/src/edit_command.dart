import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart' show createRenderSandbox;
import 'package:fluvie_cli/src/render_defines.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';

/// `fluvie edit <spec.json> "<change>" --out <file>`: refine an existing
/// `VideoSpec` with a natural-language change (the harness loads the base spec,
/// re-authors it, writes the result, and renders).
///
/// The edited spec is written to `--spec-out` (default: overwrite the input),
/// so each edit round stays reproducible.
final class EditCommand {
  /// Creates the command; `runner` and `createSandbox` are injectable for tests.
  EditCommand({
    this._runner = const IoProcessRunner(),
    this._createSandbox = createRenderSandbox,
    this._resolveFfmpeg = ensureFfmpeg,
  });

  final ProcessRunner _runner;
  final Future<Directory> Function() _createSandbox;
  final FfmpegResolver _resolveFfmpeg;

  /// The `edit` command's argument parser.
  static ArgParser buildParser() {
    final parser = ArgParser(usageLineLength: 80)
      ..addOption('out', help: 'Path of the output video file (required).')
      ..addOption('provider', help: 'LLM provider: claude (default), gemini, mistral, ollama.')
      ..addOption(
        'spec-out',
        help: 'Where to write the edited VideoSpec JSON (default: overwrite the input spec).',
      );
    addSharedRenderOptions(parser);
    return parser;
  }

  /// Runs the command for parsed [args]; returns the process exit code.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length < 2) {
      err.writeln(
        'edit needs a spec file and a change: edit <spec.json> "<change>".'
        '\n\n${buildParser().usage}',
      );
      return 64;
    }
    final specPath = args.rest.first;
    final change = args.rest.skip(1).join(' ').trim();
    if (change.isEmpty) {
      err.writeln('edit needs a non-empty change description.');
      return 64;
    }
    final baseFile = File(specPath);
    if (!baseFile.existsSync()) {
      err.writeln('Spec file not found: $specPath');
      return 64;
    }
    final outPath = args.option('out');
    if (outPath == null || outPath.isEmpty) {
      err.writeln('edit needs --out <file>.\n\n${buildParser().usage}');
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
    final specOut = File(args.option('spec-out') ?? specPath).absolute.path;
    final defines = editDefines(
      baseSpecPath: baseFile.path,
      change: change,
      specOut: specOut,
      provider: args.option('provider'),
    );
    try {
      return await captureThenEncode(
        runner: _runner,
        createSandbox: _createSandbox,
        args: args,
        key: '',
        outPath: outPath,
        frames: frames,
        flags: flags,
        extraDefines: defines,
        out: out,
        err: err,
        report: (sink) => sink.writeln('Spec $specOut'),
        resolveFfmpeg: _resolveFfmpeg,
      );
    } on CliFailure catch (failure) {
      err.writeln(failure.message);
      return 1;
    }
  }
}
