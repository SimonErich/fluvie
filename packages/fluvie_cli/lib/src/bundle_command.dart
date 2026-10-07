import 'dart:convert';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart';
import 'package:fluvie_cli/src/video_project_bundle.dart';
import 'package:path/path.dart' as p;

/// Packages, verifies, restores and renders portable authoring projects.
final class BundleCommand {
  /// Uses the same managed render command after resolving a restored project.
  const BundleCommand({this.runner = const IoProcessRunner()});

  /// Dependency-resolution process seam.
  final ProcessRunner runner;

  /// Explicit creation and replay options; evidence is included only on request.
  static ArgParser buildParser() => ArgParser()
    ..addOption('out', help: 'Output ZIP for create, or output video for replay.')
    ..addOption('dir', help: 'New unpack/replay destination.')
    ..addOption('entry', defaultsTo: 'build')
    ..addMultiOption(
      'include',
      splitCommas: false,
      help: 'Explicit finished artifact or review directory.',
    )
    ..addOption('aspect')
    ..addOption('quality')
    ..addOption('format')
    ..addOption('ffmpeg')
    ..addOption('ffprobe')
    ..addFlag('no-download', negatable: false)
    ..addFlag('json', negatable: false);

  /// Inspection never executes Dart; replay explicitly resolves and renders it.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length != 2 ||
        !{'create', 'inspect', 'unpack', 'replay'}.contains(args.rest.first)) {
      err.writeln('Use fluvie bundle <create|inspect|unpack|replay> <video.dart|bundle.zip>.');
      return 64;
    }
    final operation = args.rest.first;
    final input = args.rest.last;
    Map<String, Object?> result;
    if (operation == 'create') {
      final target = resolveFileTarget(arg: input, entry: args.option('entry')!);
      result = await VideoProjectBundle.create(
        target: target,
        output:
            args.option('out') ??
            p.join(
              target.projectDir,
              'build/fluvie',
              '${p.basenameWithoutExtension(target.path)}.fluvie.zip',
            ),
        artifacts: args.multiOption('include'),
        settings: {
          for (final key in ['aspect', 'quality', 'format'])
            if (args.option(key) != null) key: args.option(key),
        },
      );
    } else if (operation == 'inspect') {
      result = await VideoProjectBundle.inspect(input);
    } else {
      final destination = args.option('dir');
      if (destination == null) {
        throw const CliFailure('Unpack and replay require --dir naming a new directory.');
      }
      result = await VideoProjectBundle.unpack(input, destination);
      if (operation == 'replay') {
        final project = p.join(p.absolute(destination), 'project');
        final resolution = await runner.run('flutter', [
          'pub',
          'get',
          '--enforce-lockfile',
        ], workingDirectory: project);
        if (resolution.exitCode != 0) {
          throw CliFailure(
            'Replay could not preserve the pinned resolution. Use the recorded Flutter SDK.\n'
            '${resolution.stdout}\n${resolution.stderr}',
          );
        }
        final settings = result['settings'] as Map<String, Object?>? ?? const {};
        final renderArgs = RenderCommand.buildParser().parse([
          p.join(p.absolute(destination), result['entry']! as String),
          '--entry',
          result['entryFunction']! as String,
          '--project',
          project,
          for (final key in ['aspect', 'quality', 'format'])
            if (args.option(key) ?? settings[key] case final String value) ...['--$key', value],
          for (final key in ['out', 'ffmpeg', 'ffprobe'])
            if (args.option(key) case final String value) ...['--$key', value],
          if (args.flag('no-download')) '--no-download',
        ]);
        return RenderCommand().execute(renderArgs, out: out, err: err);
      }
    }
    out.writeln(
      args.flag('json')
          ? jsonEncode(result)
          : 'Bundle $operation complete: ${result['entry']} (${(result['files']! as List).length} verified file records).',
    );
    return 0;
  }
}
