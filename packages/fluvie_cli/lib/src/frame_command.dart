import 'dart:convert';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart' show createRenderSandbox;
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:path/path.dart' as p;

/// Captures one deterministic composition frame for visual review.
final class FrameCommand {
  /// Creates a frame command.
  FrameCommand({this._runner = const IoProcessRunner()});
  final ProcessRunner _runner;

  /// Exact-frame capture options.
  static ArgParser buildParser() {
    final parser = ArgParser()
      ..addOption('entry', defaultsTo: 'build', help: 'Top-level Video builder.')
      ..addOption('frame', defaultsTo: '0', help: 'Absolute frame index to capture.')
      ..addOption(
        'out',
        help: 'PNG output (default: build/fluvie/<composition>.frame_<index>.png).',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Emit the artifact path and exact frame index as JSON.',
      );
    addSharedRenderOptions(parser);
    return parser;
  }

  /// Captures the requested frame without encoding an entire video.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    final frame = int.tryParse(args.option('frame') ?? '');
    if (args.rest.length != 1 || frame == null || frame < 0) {
      err.writeln('Use `fluvie frame <file.dart> --frame <non-negative index>`.');
      return 64;
    }
    try {
      final target = resolveFileTarget(
        arg: args.rest.single,
        entry: args.option('entry') ?? 'build',
        project: args.option('project'),
      );
      validateRenderAdapters(args);
      if (args.option('renderer') != null) {
        throw const UsageFailure(
          '--renderer custom engines apply to render; inspect/frame use the managed composition engine.',
        );
      }
      final output =
          args.option('out') ??
          p.join(
            target.projectDir,
            'build',
            'fluvie',
            '${p.basenameWithoutExtension(target.path)}.frame_$frame.png',
          );
      await captureThenEncode(
        runner: _runner,
        createSandbox: createRenderSandbox,
        args: args,
        key: p.relative(target.path, from: target.projectDir),
        outPath: output,
        frames: null,
        flags: validateExportFlags(args),
        extraDefines: {'FLUVIE_OPERATION': 'frame', 'FLUVIE_FRAME': '$frame'},
        projectDirOverride: target.projectDir,
        noCacheOverride: true,
        stage: (project) =>
            stageManagedHarness(projectDir: project, runner: _runner, target: target),
        out: args.flag('json') ? StringBuffer() : out,
        err: err,
      );
      if (args.flag('json') || args.flag('machine')) {
        out.writeln(
          jsonEncode({
            'schemaVersion': 1,
            if (args.flag('machine')) 'event': 'frame',
            'frame': frame,
            'filePath': p.absolute(output),
          }),
        );
      }
      return 0;
    } on UsageFailure catch (failure) {
      err.writeln(failure.message);
      return 64;
    } on CliFailure catch (failure) {
      if (args.flag('machine')) rethrow;
      err.writeln(failure.message);
      return 1;
    }
  }
}
