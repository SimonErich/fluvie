import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/capture_process.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/process_runner.dart';

/// `fluvie list`: prints every composition key the capture harness can render.
///
/// The keys live in the example project (a Flutter package the pure-Dart CLI
/// cannot import), so `list` drives the same harness the render path uses with
/// a `FLUVIE_RENDER_LIST=true` define; the harness prints a `fluvie-keys:` line
/// the CLI parses and reprints.
final class ListCommand {
  /// Creates the command; `runner` is injectable for tests.
  ListCommand({this._runner = const IoProcessRunner()});

  final ProcessRunner _runner;

  /// The marker the harness prints its keys behind.
  static const String keysMarker = 'fluvie-keys:';

  /// The `list` command's argument parser.
  static ArgParser buildParser() => ArgParser(usageLineLength: 80)
    ..addOption(
      'project',
      help:
          'Flutter project containing the capture harness '
          '(default: the auto-discovered harness project).',
    );

  /// Runs the command; returns the exit code (`0` ok, `1` operational failure).
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    try {
      final keys = await _listKeys(resolveProjectDir(project: args.option('project')));
      out.writeln('Render keys:');
      for (final key in keys) {
        out.writeln('  $key');
      }
      return 0;
    } on CliFailure catch (failure) {
      err.writeln(failure.message);
      return 1;
    }
  }

  Future<List<String>> _listKeys(String projectDir) async {
    final ProcessRunResult result;
    try {
      result = await _runner.run('flutter', const [
        'test',
        '--no-pub',
        'test/render/capture_harness_test.dart',
        '--dart-define=FLUVIE_RENDER_LIST=true',
      ], workingDirectory: projectDir);
    } on ProcessException catch (error) {
      throw CliFailure(
        'Could not run "flutter test" in "$projectDir" (${error.message}). Install Flutter and '
        'make sure `flutter` is on PATH (https://docs.flutter.dev/get-started/install), or pass '
        '--project pointing at a project whose toolchain is set up.',
      );
    }
    if (result.exitCode != 0) {
      throw CliFailure(
        'Listing the render keys (flutter test in "$projectDir") failed with exit code '
        '${result.exitCode}.\n${result.stderr}',
      );
    }
    return _parseKeys(result.stdout);
  }

  /// Parses the `fluvie-keys: a, b, c` line out of the harness [output].
  List<String> _parseKeys(String output) {
    for (final line in const LineSplitter().convert(output)) {
      final index = line.indexOf(keysMarker);
      if (index < 0) continue;
      return [
        for (final key in line.substring(index + keysMarker.length).split(','))
          if (key.trim().isNotEmpty) key.trim(),
      ];
    }
    throw const CliFailure(
      'The harness printed no "$keysMarker" line; the capture harness must run a '
      'matching fluvie version that supports FLUVIE_RENDER_LIST.',
    );
  }
}
