import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart' show createRenderSandbox;
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:path/path.dart' as p;

/// Inspects the actual compiled composition, without capturing video frames.
final class InspectCommand {
  /// Creates the command with injectable process and workspace seams.
  InspectCommand({this._runner = const IoProcessRunner(), this._resolveFfmpeg = ensureFfmpeg});
  final ProcessRunner _runner;
  final FfmpegResolver _resolveFfmpeg;

  /// Inspection options.
  static ArgParser buildParser() {
    final parser = ArgParser()
      ..addOption('entry', defaultsTo: 'build', help: 'Top-level Video builder.')
      ..addFlag(
        'json',
        negatable: false,
        help: 'Emit machine-readable compiled composition metadata.',
      );
    addSharedRenderOptions(parser);
    return parser;
  }

  /// Compiles and probes the composition through the managed package engine.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length != 1) {
      err.writeln('inspect needs one composition file.');
      return 64;
    }
    final resultDir = await Directory.systemTemp.createTemp('fluvie_inspection_');
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
      final resultPath = p.join(resultDir.path, 'inspection.json');
      await captureThenEncode(
        runner: _runner,
        createSandbox: createRenderSandbox,
        args: args,
        key: p.relative(target.path, from: target.projectDir),
        outPath: resultPath,
        frames: null,
        flags: validateExportFlags(args),
        extraDefines: const {'FLUVIE_OPERATION': 'inspect'},
        projectDirOverride: target.projectDir,
        noCacheOverride: true,
        stage: (project) =>
            stageManagedHarness(projectDir: project, runner: _runner, target: target),
        out: StringBuffer(),
        err: err,
        resolveFfmpeg: _resolveFfmpeg,
      );
      final text = File(resultPath).readAsStringSync();
      final json = jsonDecode(text) as Map<String, Object?>;
      if (args.flag('json') || args.flag('machine')) {
        out.writeln(jsonEncode({if (args.flag('machine')) 'event': 'inspection', ...json}));
      } else {
        out
          ..writeln(
            '${p.basename(target.path)}: ${json['width']}×${json['height']} at ${json['fps']} fps',
          )
          ..writeln(
            '${json['totalFrames']} frames, ${(json['scenes']! as List).length} scenes, audio: ${json['hasAudio']}',
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
    } finally {
      await resultDir.delete(recursive: true);
    }
  }
}
