// Public injection names remain stable while their backing fields stay private.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/ai_preflight.dart';
import 'package:fluvie_cli/src/authoring_context.dart';
import 'package:fluvie_cli/src/capture_process.dart' show resolveProjectDir;
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/dart_authoring_workflow.dart';
import 'package:fluvie_cli/src/dart_edit_command.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart' show createRenderSandbox;
import 'package:fluvie_cli/src/render_defines.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:fluvie_cli/src/spec_authoring.dart';
import 'package:path/path.dart' as p;

/// Refines native Dart or a `VideoSpec` with a natural-language change.
///
/// Dart edits preserve untouched bytes, validate a staged sibling, then publish
/// atomically with a `.fluvie.bak` backup. Spec edits publish readable Flutter
/// code plus their JSON before rendering; `--no-render` only authors artifacts.
final class EditCommand {
  /// Creates the command; `runner` and `createSandbox` are injectable for tests.
  EditCommand({
    this._runner = const IoProcessRunner(),
    this._createSandbox = createRenderSandbox,
    this._resolveFfmpeg = ensureFfmpeg,
    Map<String, String>? environment,
    Future<String> Function(ArgResults args, String source)? requestDartEdits,
    Future<void> Function(ArgResults args, File pending)? validateDart,
  }) : _environment = environment ?? Platform.environment,
       _requestDartEdits = requestDartEdits,
       _validateDart = validateDart;

  final ProcessRunner _runner;
  final Future<Directory> Function() _createSandbox;
  final FfmpegResolver _resolveFfmpeg;
  final Map<String, String> _environment;
  final Future<String> Function(ArgResults, String)? _requestDartEdits;
  final Future<void> Function(ArgResults, File)? _validateDart;

  /// The `edit` command's argument parser.
  static ArgParser buildParser() {
    final parser = ArgParser(usageLineLength: 80)
      ..addOption('out', help: 'Output video path (default: build/fluvie/<spec>.mp4).')
      ..addOption('entry', defaultsTo: 'build', help: 'Top-level Video builder for Dart edits.')
      ..addOption('dart-out', help: 'Write readable Flutter composition code to this .dart file.')
      ..addFlag(
        'no-render',
        negatable: false,
        help: 'Edit the spec and Dart output without rendering a video.',
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
        help: 'Where to write the edited VideoSpec JSON (default: overwrite the input spec).',
      );
    addSharedRenderOptions(parser);
    return parser;
  }

  /// Runs the command for parsed [args]; returns the process exit code.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length < 2) {
      err.writeln(
        'edit needs a source file and a change: edit <file.dart|spec.json> "<change>".'
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
    var project = resolveProjectDir(project: args.option('project'));
    final baseFile = File(
      specPath.endsWith('.dart') && args.option('project') == null
          ? p.absolute(specPath)
          : resolveAuthoringInputPath(project, specPath),
    );
    if (!baseFile.existsSync()) {
      err.writeln('Source file not found: $specPath');
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
    final specOut = resolveAuthoringInputPath(project, args.option('spec-out') ?? specPath);
    final defines = {
      ...editDefines(
        baseSpecPath: baseFile.path,
        change: change,
        specOut: specOut,
        provider: args.option('provider'),
      ),
      if (args.flag('no-render')) 'FLUVIE_OPERATION': 'author',
    };
    try {
      validateAiEnvironment(_environment, provider: args.option('provider'));
      if (specPath.endsWith('.dart')) {
        if (args.option('project') == null) {
          project = resolveFileTarget(arg: baseFile.path, entry: args.option('entry')!).projectDir;
        }
        if (args.option('dart-out') != null || args.option('spec-out') != null) {
          throw const CliFailure(
            'Native Dart edits update the input file. Omit --dart-out and --spec-out.',
          );
        }
        final workflow = DartAuthoringWorkflow(
          args: args,
          runner: _runner,
          createSandbox: _createSandbox,
          environment: _environment,
          resolveFfmpeg: _resolveFfmpeg,
          project: project,
          err: err,
        );
        return await executeDartEdit(
          args: args,
          file: baseFile,
          out: out,
          err: err,
          requestEdits: (source) =>
              _requestDartEdits?.call(args, source) ?? workflow.requestEdits(source),
          repairEdits: _requestDartEdits == null
              ? (source, feedback) => workflow.requestEdits(source, feedback: feedback)
              : null,
          validate: (candidate) =>
              _validateDart?.call(args, candidate) ?? workflow.validate(candidate),
          render: (source) => workflow.render(source, out: out),
        );
      }
      final outPath =
          args.option('out') ??
          defaultRenderOutput(
            resolveProjectDir(project: args.option('project')),
            specPath,
            format: flags.format,
          );
      final code = await authorThenRender(
        runner: _runner,
        createSandbox: _createSandbox,
        args: args,
        outPath: outPath,
        specOut: specOut,
        dartName: p.basename(specPath).replaceFirst(RegExp(r'\.fluvie\.json$|\.json$'), ''),
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
