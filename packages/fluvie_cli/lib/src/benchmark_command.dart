import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/ai_preflight.dart';
import 'package:fluvie_cli/src/authoring_benchmark.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/edit_command.dart';
import 'package:fluvie_cli/src/generate_command.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:fluvie_cli/src/review_command.dart';
import 'package:fluvie_cli/src/stage_harness.dart';
import 'package:path/path.dart' as p;

part 'benchmark_command_case.dart';

/// Measures real model authoring and edits using the public CLI workflows.
final class BenchmarkCommand {
  /// Pins provider configuration while allowing deterministic command tests.
  BenchmarkCommand({Map<String, String>? environment})
    : environment = environment ?? Platform.environment;

  /// Provider credentials stay in memory and are never written to reports.
  final Map<String, String> environment;

  /// Requires an explicit model identity so recorded runs remain comparable.
  static ArgParser buildParser() {
    final parser = ArgParser()
      ..addOption('provider')
      ..addOption('model', help: 'Pinned model id, or FLUVIE_AI_MODEL.')
      ..addOption('out-dir', help: 'New benchmark evidence directory.')
      ..addFlag(
        'fixture-mode',
        negatable: false,
        help: 'Label a configured test provider as simulated.',
      )
      ..addFlag('json', negatable: false);
    addSharedRenderOptions(parser);
    return parser;
  }

  /// Runs every case and records failures without hiding subsequent results.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length != 1 || args.option('project') == null) {
      err.writeln('Use fluvie benchmark <suite.json> --project <fixture-project> --model <model>.');
      return 64;
    }
    final provider = validateAiEnvironment(environment, provider: args.option('provider'));
    final model = args.option('model') ?? environment['FLUVIE_AI_MODEL'];
    if (model == null || model.isEmpty) {
      throw const CliFailure('Pin --model for a reproducible provider benchmark.');
    }
    final suiteFile = File(args.rest.single);
    if (suiteFile.lengthSync() > 262144) throw const CliFailure('Benchmark suite exceeds 256 KiB.');
    final suite = jsonDecode(await suiteFile.readAsString()) as Map<String, Object?>;
    final project = p.absolute(args.option('project')!);
    final directory = Directory(
      args.option('out-dir') ?? p.join(project, 'build/fluvie/benchmarks', uniqueStageId()),
    );
    if (directory.existsSync()) throw const CliFailure('Choose a new benchmark output directory.');
    final sources = <String, String>{};
    final report = await runAuthoringBenchmark(
      suite: suite,
      output: directory,
      provider: provider,
      model: model,
      realProvider: !args.flag('fixture-mode'),
      execute: (task, output) => _case(
        task,
        output,
        args: args,
        project: project,
        sources: sources,
        provider: provider,
        model: model,
        err: err,
      ),
    );
    out.writeln(
      args.flag('json')
          ? jsonEncode(report)
          : 'Benchmark ${report['ok'] == true ? 'passed' : 'failed'}: ${p.join(directory.path, 'benchmark.json')}',
    );
    return report['ok'] == true ? 0 : 1;
  }
}
