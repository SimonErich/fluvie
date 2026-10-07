import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/capture_process.dart' show isFluvieProject;
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
    ..addOption('fluvie-path', help: 'Use an unpublished local Fluvie package or checkout.')
    ..addFlag(
      'with-ai',
      negatable: false,
      help: 'Add fluvie_ai for built-in generation and editing.',
    )
    ..addFlag('with-lints', negatable: false, help: 'Add optional Fluvie editor lints.')
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
        fluviePath:
            args.option('fluvie-path') ??
            (isFluvieProject(dir.path) ? null : await installedFluviePath()),
        withAi: args.flag('with-ai'),
        withLints: args.flag('with-lints'),
      );
    } on CliFailure catch (failure) {
      err.writeln(failure.message);
      return 1;
    }
  }
}

/// Local path activation keeps an unpublished CLI and core on the same checkout.
/// Hosted installations have no sibling core checkout and use the package version.
Future<String?> installedFluviePath() async {
  final uri = await Isolate.resolvePackageUri(Uri.parse('package:fluvie_cli/fluvie_cli.dart'));
  if (uri == null || uri.scheme != 'file') return null;
  final library = File.fromUri(uri);
  final cliRoot = p.dirname(p.dirname(library.resolveSymbolicLinksSync()));
  final marker = File(p.join(p.dirname(p.dirname(uri.toFilePath())), 'fluvie-source.json'));
  if (marker.existsSync()) {
    final metadata = jsonDecode(marker.readAsStringSync()) as Map<String, Object?>;
    final source = metadata['sourceRoot'];
    if (source is String) {
      final core = p.join(source, 'packages', 'fluvie');
      if (File(p.join(core, 'pubspec.yaml')).existsSync()) return core;
    }
  }
  final core = p.join(p.dirname(cliRoot), 'fluvie');
  return File(p.join(core, 'pubspec.yaml')).existsSync() ? core : null;
}
