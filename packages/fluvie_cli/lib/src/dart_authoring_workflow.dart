import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/docs.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/inspect_command.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:fluvie_cli/src/validate_command.dart';
import 'package:path/path.dart' as p;

/// The managed AI transport, compiled validation, and capture for native source
/// edits. The source publication transaction is independent of this host.
final class DartAuthoringWorkflow {
  /// Creates the workflow with a shared process/toolchain configuration.
  const DartAuthoringWorkflow({
    required this.args,
    required this.runner,
    required this.createSandbox,
    required this.environment,
    required this.resolveFfmpeg,
    required this.project,
    required this.err,
  });

  final ArgResults args;
  final ProcessRunner runner;
  final Future<Directory> Function() createSandbox;
  final Map<String, String> environment;
  final FfmpegResolver resolveFfmpeg;
  final String project;
  final StringSink err;

  /// Authors exact replacements using an immutable source snapshot.
  Future<String> requestEdits(String source, {String feedback = ''}) async {
    final directory = await Directory.systemTemp.createTemp('fluvie_dart_author_');
    try {
      final snapshot = File(p.join(directory.path, 'original.dart'));
      await snapshot.writeAsString(source);
      final patches = p.join(directory.path, 'edits.json');
      await captureThenEncode(
        runner: runner,
        createSandbox: createSandbox,
        args: args,
        key: '',
        outPath: patches,
        frames: null,
        flags: validateExportFlags(args),
        extraDefines: {
          'FLUVIE_OPERATION': 'author',
          'FLUVIE_AI_DART_SOURCE': snapshot.path,
          'FLUVIE_AI_DART_API_B64': base64Encode(
            utf8.encode(
              dartEditingContext('${args.rest.skip(1).join(' ')}\n$source'),
            ),
          ),
          if (args.option('ai-trace') case final String trace)
            'FLUVIE_AI_TRACE_OUT': feedback.isEmpty
                ? p.absolute(trace)
                : '${p.absolute(trace)}.repair-${p.basename(directory.path)}.json',
          'FLUVIE_AI_PROMPT':
              '${args.rest.skip(1).join(' ')}${feedback.isEmpty ? '' : '\nThe previous candidate failed Dart validation. Repair these diagnostics using the unchanged original source:\n$feedback'}',
          'FLUVIE_RENDER_SPEC_OUT': patches,
          if (args.option('provider') != null) 'FLUVIE_AI_PROVIDER': args.option('provider')!,
        },
        projectDirOverride: project,
        environment: environment,
        stage: (project) => stageManagedHarness(
          projectDir: project,
          runner: runner,
          author: true,
          dartEdit: true,
        ),
        out: StringBuffer(),
        err: err,
        resolveFfmpeg: resolveFfmpeg,
      );
      return await File(patches).readAsString();
    } finally {
      await directory.delete(recursive: true);
    }
  }

  /// Requires both valid Dart and a compilable, mountable Video builder before
  /// replacing the original source. Relative imports remain in their context.
  Future<void> validate(File candidate) async {
    final diagnostics = StringBuffer();
    final staticCode = await const ValidateCommand().execute(
      ValidateCommand.buildParser().parse([candidate.path, '--project', project]),
      out: diagnostics,
      err: diagnostics,
    );
    if (staticCode != 0) {
      throw CliFailure('Dart edit did not compile:\n$diagnostics', code: 'dart_validation_failed');
    }
    final code = await InspectCommand(runner: runner, resolveFfmpeg: resolveFfmpeg).execute(
      InspectCommand.buildParser().parse([
        candidate.path,
        '--entry',
        args.option('entry') ?? 'build',
        ...renderArguments(),
      ]),
      out: StringBuffer(),
      err: diagnostics,
    );
    if (code != 0) throw CliFailure('Dart edit could not prepare its composition:\n$diagnostics');
  }

  /// Renders the published source, rather than its temporary authoring reply.
  Future<int> render(String source, {required StringSink out}) {
    final target = resolveFileTarget(
      arg: source,
      entry: args.option('entry') ?? 'build',
      project: project,
    );
    return captureThenEncode(
      runner: runner,
      createSandbox: createSandbox,
      args: args,
      key: p.relative(source, from: project),
      outPath:
          args.option('out') ?? defaultRenderOutput(project, source, format: args.option('format')),
      frames: validateFrames(args.option('frames')),
      flags: validateExportFlags(args),
      extraDefines: const {},
      projectDirOverride: project,
      stage: (project) => stageManagedHarness(projectDir: project, runner: runner, target: target),
      out: out,
      err: err,
      environment: environment,
      resolveFfmpeg: resolveFfmpeg,
    );
  }

  List<String> renderArguments() => [
    '--project',
    project,
    for (final option in ['ffmpeg', 'ffprobe', 'toolchain'])
      if (args.option(option) != null) ...['--$option', args.option(option)!],
    for (final flag in ['no-download', 'enable-impeller', 'verbose'])
      if (args.flag(flag)) '--$flag',
  ];
}
