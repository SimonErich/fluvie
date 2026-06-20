import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart' show createRenderSandbox;
import 'package:fluvie_cli/src/render_defines.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';

/// `fluvie generate "<prompt>" --out <file>`: author a `VideoSpec` from natural
/// language (inside the capture harness, which has the AI package and network),
/// write it to `--spec-out`, then capture and encode it like any render.
///
/// The model runs only at authoring time; the written spec is the reproducible
/// artifact. Provider and API keys come from the environment
/// (`FLUVIE_AI_PROVIDER`, `ANTHROPIC_API_KEY`, ...), inherited by the harness.
final class GenerateCommand {
  /// Creates the command; `runner` and `createSandbox` are injectable for tests.
  GenerateCommand({
    this._runner = const IoProcessRunner(),
    this._createSandbox = createRenderSandbox,
    this._resolveFfmpeg = ensureFfmpeg,
  });

  final ProcessRunner _runner;
  final Future<Directory> Function() _createSandbox;
  final FfmpegResolver _resolveFfmpeg;

  /// The `generate` command's argument parser.
  static ArgParser buildParser() {
    final parser = ArgParser(usageLineLength: 80)
      ..addOption('out', help: 'Path of the output video file (required).')
      ..addOption('provider', help: 'LLM provider: claude (default), gemini, mistral, ollama.')
      ..addOption(
        'spec-out',
        help: 'Where to write the authored VideoSpec JSON (default: <out>.fluvie.json).',
      );
    addSharedRenderOptions(parser);
    return parser;
  }

  /// Derives the spec-out path from [outPath] by swapping its extension for
  /// `.fluvie.json`.
  static String deriveSpecOut(String outPath) {
    final slash = outPath.lastIndexOf(RegExp(r'[/\\]'));
    final dot = outPath.lastIndexOf('.');
    return dot > slash ? '${outPath.substring(0, dot)}.fluvie.json' : '$outPath.fluvie.json';
  }

  /// Runs the command for parsed [args]; returns the process exit code.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    final prompt = args.rest.join(' ').trim();
    if (prompt.isEmpty) {
      err.writeln('generate needs a prompt.\n\n${buildParser().usage}');
      return 64;
    }
    final outPath = args.option('out');
    if (outPath == null || outPath.isEmpty) {
      err.writeln('generate needs --out <file>.\n\n${buildParser().usage}');
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
    final specOut = File(args.option('spec-out') ?? deriveSpecOut(outPath)).absolute.path;
    final defines = generateDefines(
      prompt: prompt,
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
