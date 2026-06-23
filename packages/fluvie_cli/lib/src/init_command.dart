import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/init_existing_project.dart';
import 'package:fluvie_cli/src/init_new_project.dart';
import 'package:fluvie_cli/src/init_prompt.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/project_context.dart';

/// `fluvie init`: get a good start into Fluvie.
///
/// Inside an existing Flutter project it drops a starter composition (written in
/// real Flutter widget code) and, when asked, wires the render harness so
/// `fluvie render <key>` works. Outside a Flutter project it scaffolds a minimal,
/// runnable, testable Fluvie project with `flutter create`.
///
/// `init` is the one interactive command: it prompts for the file location and
/// the project name, each with a default the user accepts by pressing Enter.
/// Pass `--yes` (and the flags) to run it non-interactively.
final class InitCommand {
  /// Creates the command; `runner`, `readLine` and `workingDirectory` are
  /// injectable for tests.
  InitCommand({
    this._runner = const IoProcessRunner(),
    this._readLine,
    Directory? workingDirectory,
  }) : _workingDirectory = workingDirectory ?? Directory.current;

  final ProcessRunner _runner;
  final LineReader? _readLine;
  final Directory _workingDirectory;

  /// The `init` command's argument parser.
  static ArgParser buildParser() => ArgParser(usageLineLength: 80)
    ..addOption('name', help: 'Composition name (the render key and file name). Default: starter.')
    ..addOption('path', help: 'Where to write the composition in an existing project.')
    ..addOption('dir', help: 'Directory for a new project (when not in a Flutter project).')
    ..addFlag(
      'render',
      defaultsTo: true,
      help: 'Also scaffold the render harness in an existing project (--no-render to skip).',
    )
    ..addFlag('force', negatable: false, help: 'Overwrite files that already exist.')
    ..addFlag('yes', abbr: 'y', negatable: false, help: 'Accept defaults; do not prompt.');

  /// Runs the command; returns the exit code (`0` ok, `1` operational failure).
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    final interactive = !args.flag('yes');
    final prompt = InitPrompt(out: out, readLine: _readLine);
    final name = args.option('name') ?? 'starter';
    final context = detectProjectContext(_workingDirectory);
    try {
      if (context.isFlutterProject) {
        return await initExistingProject(
          context: context,
          prompt: prompt,
          interactive: interactive,
          name: name,
          pathOverride: args.option('path'),
          withRender: args.flag('render'),
          force: args.flag('force'),
          out: out,
          err: err,
        );
      }
      return await initNewProject(
        runner: _runner,
        prompt: prompt,
        interactive: interactive,
        cwd: _workingDirectory,
        name: name,
        dirOverride: args.option('dir'),
        out: out,
        err: err,
      );
    } on CliFailure catch (failure) {
      err.writeln(failure.message);
      return 1;
    }
  }
}
