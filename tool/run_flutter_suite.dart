import 'dart:io';

import 'src/flutter_suite_batches.dart';

/// Runs ordinary Flutter suites, batching large suites without skipping tests.
Future<void> main(List<String> arguments) async {
  final files = discoverFlutterTests(Directory('test'));
  if (arguments.any(
    (argument) =>
        argument.startsWith('--coverage-path') ||
        argument == '--merge-coverage' ||
        argument == '--branch-coverage',
  )) {
    stderr.writeln('Batching requires fresh line-only coverage with managed output paths');
    exitCode = 64;
    return;
  }
  final batches = flutterSuiteBatches(files);
  final evidence = Directory('build/studio-suite-evidence')..createSync(recursive: true);
  final scratch = evidence.createTempSync('run-').absolute;
  final runtimeRoot = Directory.systemTemp.createTempSync('.studio-flutter-runtime-');
  final temp = createFlutterRuntimeDirectory(runtimeRoot);
  try {
    stdout
      ..writeln(
        'Flutter suite: ${files.length} discovered files, ${batches.length} bounded batches',
      )
      ..writeln('Fresh JSON and LCOV evidence: ${scratch.path}');
    var batch = 0;
    exitCode = await executeFlutterBatches(
      batches: batches,
      arguments: arguments,
      run: (args) async {
        stdout.writeln('Flutter batch ${++batch}/${batches.length}');
        final process = await Process.start(
          'flutter',
          [...args, '--file-reporter', 'json:${scratch.path}/batch-${batch - 1}.jsonl'],
          environment: {'TMPDIR': temp.path},
          mode: ProcessStartMode.inheritStdio,
        );
        return process.exitCode;
      },
      verify: (index) async {
        final report = File('${scratch.path}/batch-$index.jsonl');
        return report.existsSync() && successfulTestRun(report.readAsStringSync());
      },
      coveragePath: (index) => '${scratch.path}/batch-$index.info',
      read: (path) async {
        final file = File(path);
        return file.existsSync() ? file.readAsStringSync() : null;
      },
      write: (report) async {
        final output = File('coverage/lcov.info');
        output.parent.createSync(recursive: true);
        output.writeAsStringSync(report);
      },
    );
  } on Object catch (error) {
    stderr.writeln('Flutter batch runner failed: $error');
    exitCode = 1;
  } finally {
    // Retain JSON and LCOV evidence; only this run's disposable runtime is removed.
    runtimeRoot.deleteSync(recursive: true);
  }
}
