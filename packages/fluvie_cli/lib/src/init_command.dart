import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/init_project.dart';
import 'package:fluvie_cli/src/init_support.dart';
import 'package:path/path.dart' as p;

/// `fluvie init`: scaffold a Fluvie project.
///
/// The project is a directory holding a composition file, an `assets/` folder,
/// and a `pubspec.yaml`. That is all: no app, no `main.dart`, no capture
/// harness, no registry, and no platform directories. The CLI generates whatever
/// a render or a preview needs, per invocation.
///
/// Run in an existing Flutter project it drops the composition in and leaves the
/// rest of the project alone.
final class InitCommand {
  /// Creates the command; `workingDirectory` is injectable for tests.
  InitCommand({Directory? workingDirectory})
    : _workingDirectory = workingDirectory ?? Directory.current;

  final Directory _workingDirectory;

  /// The `init` command's argument parser.
  static ArgParser buildParser() => ArgParser(usageLineLength: 80)
    ..addOption(
      'name',
      help: 'Composition file name, without the extension. Default: example_video.',
    )
    ..addOption('dir', help: 'Directory to scaffold into. Default: the working directory.')
    ..addFlag('force', negatable: false, help: 'Overwrite files that already exist.');

  /// Runs the command; returns the exit code (`0` ok, `1` operational failure).
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    final name = args.option('name') ?? 'example_video';
    final dirOption = args.option('dir');
    final dir = dirOption == null
        ? _workingDirectory
        : Directory(p.join(_workingDirectory.path, dirOption));
    final force = args.flag('force');
    try {
      if (!force) assertScaffoldable(dir);
      dir.createSync(recursive: true);
      out.writeln('Scaffolding a Fluvie project in ${dir.path}');
      return await initProject(
        dir: dir,
        fileName: '${compositionSlug(name)}.dart',
        force: force,
        out: out,
        err: err,
      );
    } on CliFailure catch (failure) {
      err.writeln(failure.message);
      return 1;
    }
  }
}
