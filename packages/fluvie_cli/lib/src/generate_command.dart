import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/codegen.dart';
import 'package:fluvie_cli/src/ai_preflight.dart';
import 'package:fluvie_cli/src/capture_process.dart' show resolveProjectDir;
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart' show createRenderSandbox;
import 'package:fluvie_cli/src/render_defines.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:fluvie_cli/src/spec_authoring.dart';

/// Authors a readable Flutter composition and matching `VideoSpec`, publishes
/// both before capture, then renders the Dart output with the managed host.
///
/// `--no-render` stops after publication. The model runs only during authoring;
/// the Dart and JSON artifacts can be reviewed and rendered without a provider.
/// Provider and API keys come from the environment
/// (`FLUVIE_AI_PROVIDER`, `ANTHROPIC_API_KEY`, ...), inherited by the harness.
final class GenerateCommand {
  /// Creates the command; `runner` and `createSandbox` are injectable for tests.
  GenerateCommand({
    this._runner = const IoProcessRunner(),
    this._createSandbox = createRenderSandbox,
    this._resolveFfmpeg = ensureFfmpeg,
    Map<String, String>? environment,
  }) : _environment = environment ?? Platform.environment;

  final ProcessRunner _runner;
  final Future<Directory> Function() _createSandbox;
  final FfmpegResolver _resolveFfmpeg;
  final Map<String, String> _environment;

  /// The `generate` command's argument parser.
  static ArgParser buildParser() {
    final parser = ArgParser(usageLineLength: 80)
      ..addOption('out', help: 'Output video path (default: build/fluvie/generated.mp4).')
      ..addOption('dart-out', help: 'Write readable Flutter composition code to this .dart file.')
      ..addFlag(
        'no-render',
        negatable: false,
        help: 'Author the reproducible spec and Dart output without rendering a video.',
      )
      ..addOption('context', help: 'Explicit story/context text to supply to the author.')
      ..addOption('catalog', help: 'Selected content-bound asset catalog from fluvie assets.')
      ..addFlag(
        'image-evidence',
        negatable: false,
        help: 'Send up to four selected contact sheets from --catalog to the AI provider.',
      )
      ..addMultiOption(
        'context-file',
        splitCommas: false,
        help: 'Explicit story text file (repeatable; up to four, 8192 bytes each).',
      )
      ..addOption(
        'assets',
        help: 'Asset directory for factual inventory (default: project assets/).',
      )
      ..addOption(
        'ai-trace',
        help: 'Explicit JSON evidence path for model prompts, replies and latency.',
      )
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
    try {
      validateAiEnvironment(_environment, provider: args.option('provider'));
      final projectDir = resolveProjectDir(project: args.option('project'));
      final outPath =
          args.option('out') ?? defaultRenderOutput(projectDir, 'generated', format: flags.format);
      final specOut = File(args.option('spec-out') ?? deriveSpecOut(outPath)).absolute.path;
      final defines = {
        ...generateDefines(prompt: prompt, specOut: specOut, provider: args.option('provider')),
        if (args.flag('no-render')) 'FLUVIE_OPERATION': 'author',
      };
      final code = await authorThenRender(
        runner: _runner,
        createSandbox: _createSandbox,
        args: args,
        outPath: outPath,
        specOut: specOut,
        frames: frames,
        flags: flags,
        defines: defines,
        out: out,
        err: err,
        resolveFfmpeg: _resolveFfmpeg,
        environment: _environment,
      );
      return code;
    } on CliFailure catch (failure) {
      if (args.flag('machine')) rethrow;
      err.writeln(failure.message);
      return 1;
    }
  }
}

/// Converts a validated authored spec into a readable Flutter builder.
void writeAuthoredDart(String specPath, String dartPath) {
  try {
    final json = jsonDecode(File(specPath).readAsStringSync());
    if (json is! Map<String, Object?>) throw const FormatException('Expected a JSON object.');
    final source = printVideoSpecJson(json);
    File(dartPath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(source);
  } on FormatException catch (error) {
    throw CliFailure('Could not emit Flutter code from "$specPath": ${error.message}');
  }
}
