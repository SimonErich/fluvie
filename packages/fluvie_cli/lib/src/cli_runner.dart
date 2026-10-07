import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/assets_command.dart';
import 'package:fluvie_cli/src/benchmark_command.dart';
import 'package:fluvie_cli/src/bundle_command.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/cli_terminal.dart';
import 'package:fluvie_cli/src/docs_command.dart';
import 'package:fluvie_cli/src/doctor_command.dart';
import 'package:fluvie_cli/src/edit_command.dart';
import 'package:fluvie_cli/src/ffmpeg_command.dart';
import 'package:fluvie_cli/src/frame_command.dart';
import 'package:fluvie_cli/src/generate_command.dart';
import 'package:fluvie_cli/src/init_command.dart';
import 'package:fluvie_cli/src/inspect_command.dart';
import 'package:fluvie_cli/src/list_command.dart';
import 'package:fluvie_cli/src/preview_command.dart';
import 'package:fluvie_cli/src/render_command.dart';
import 'package:fluvie_cli/src/review_command.dart';
import 'package:fluvie_cli/src/session_command.dart';
import 'package:fluvie_cli/src/validate_command.dart';
import 'package:fluvie_cli/src/workspace_command.dart';

part 'cli_usage.dart';

/// BSD `EX_USAGE`: the command line was used incorrectly.
const int exitUsage = 64;

/// Parses [args] and runs the requested command, writing human-readable
/// output to [out] and errors to [err]. Returns the process exit code.
///
/// `render` is injectable so wiring tests can run without spawning a single
/// process; the default constructs the real command.
Future<int> run(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  RenderCommand? render,
  ListCommand? list,
  GenerateCommand? generate,
  EditCommand? edit,
  FfmpegCommand? ffmpeg,
  InitCommand? init,
  PreviewCommand? preview,
  DocsCommand docs = const DocsCommand(),
  InspectCommand? inspect,
  FrameCommand? frame,
  DoctorCommand? doctor,
  AssetsCommand? assets,
  ValidateCommand? validate,
  ReviewCommand? review,
}) async {
  final terminal = CliTerminal(
    out: out,
    err: err,
    machine: args.contains('--machine'),
    stage: args.isEmpty ? 'cli' : args.first,
  );
  final diagnostics = terminal.err;
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.')
    ..addCommand('init', InitCommand.buildParser())
    ..addCommand('render', RenderCommand.buildParser())
    ..addCommand('preview', PreviewCommand.buildParser())
    ..addCommand('workspace', WorkspaceCommand.buildParser())
    ..addCommand('session', SessionCommand.buildParser())
    ..addCommand('bundle', BundleCommand.buildParser())
    ..addCommand('benchmark', BenchmarkCommand.buildParser())
    ..addCommand('generate', GenerateCommand.buildParser())
    ..addCommand('edit', EditCommand.buildParser())
    ..addCommand('list', ListCommand.buildParser())
    ..addCommand('ffmpeg', FfmpegCommand.buildParser())
    ..addCommand('docs', DocsCommand.buildParser())
    ..addCommand('inspect', InspectCommand.buildParser())
    ..addCommand('frame', FrameCommand.buildParser())
    ..addCommand('doctor', DoctorCommand.buildParser())
    ..addCommand('assets', AssetsCommand.buildParser())
    ..addCommand('validate', ValidateCommand.buildParser())
    ..addCommand('review', ReviewCommand.buildParser());
  for (final subcommand in parser.commands.values) {
    if (!subcommand.options.containsKey('help')) {
      subcommand.addFlag('help', abbr: 'h', negatable: false, help: 'Show command usage.');
    }
  }

  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    diagnostics
      ..writeln(e.message)
      ..writeln()
      ..writeln(_usage(parser));
    return terminal.finish(exitUsage);
  }

  if (results.flag('help')) {
    out.writeln(_usage(parser));
    return 0;
  }

  final command = results.command;
  if (command == null) {
    diagnostics.writeln(_usage(parser));
    return terminal.finish(exitUsage);
  }
  if (command.flag('help')) {
    out.writeln('fluvie ${command.name}\n\n${parser.commands[command.name]!.usage}');
    return 0;
  }
  try {
    final code = await switch (command.name) {
      'init' => (init ?? InitCommand()).execute(command, out: out, err: diagnostics),
      'preview' => (preview ?? PreviewCommand()).execute(command, out: out, err: diagnostics),
      'workspace' => const WorkspaceCommand().execute(command, out: out, err: diagnostics),
      'session' => const SessionCommand().execute(command, out: out, err: diagnostics),
      'bundle' => const BundleCommand().execute(command, out: out, err: diagnostics),
      'benchmark' => BenchmarkCommand().execute(command, out: out, err: diagnostics),
      'list' => (list ?? ListCommand()).execute(command, out: out, err: diagnostics),
      'generate' => (generate ?? GenerateCommand()).execute(command, out: out, err: diagnostics),
      'edit' => (edit ?? EditCommand()).execute(command, out: out, err: diagnostics),
      'ffmpeg' => (ffmpeg ?? FfmpegCommand()).execute(command, out: out, err: diagnostics),
      'docs' => Future<int>.sync(() => docs.execute(command, out: out, err: diagnostics)),
      'inspect' => (inspect ?? InspectCommand()).execute(command, out: out, err: diagnostics),
      'frame' => (frame ?? FrameCommand()).execute(command, out: out, err: diagnostics),
      'doctor' => (doctor ?? DoctorCommand()).execute(command, out: out, err: diagnostics),
      'assets' => (assets ?? AssetsCommand()).execute(command, out: out, err: diagnostics),
      'validate' => (validate ?? const ValidateCommand()).execute(
        command,
        out: out,
        err: diagnostics,
      ),
      'review' => (review ?? ReviewCommand()).execute(command, out: out, err: diagnostics),
      _ => (render ?? RenderCommand()).execute(command, out: out, err: diagnostics),
    };
    return terminal.finish(code);
  } on CliFailure catch (failure) {
    diagnostics.writeln(failure.message);
    return terminal.finish(1, failure: failure);
  } on FileSystemException catch (failure) {
    diagnostics.writeln(
      'Could not access "${failure.path ?? 'project files'}": ${failure.message}.',
    );
    return terminal.finish(1);
  } on ProcessException catch (failure) {
    diagnostics.writeln('Could not run "${failure.executable}": ${failure.message}.');
    return terminal.finish(1);
  } on FormatException catch (failure) {
    diagnostics.writeln('Invalid input: ${failure.message}');
    return terminal.finish(1);
  }
}
