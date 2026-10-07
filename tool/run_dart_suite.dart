import 'dart:io';

import 'src/flutter_suite_batches.dart' show mergeLineCoverage, successfulTestRun;

/// Runs the serial, tag-filtered Dart coverage gate using fresh evidence only.
Future<void> main() async {
  final evidence = Directory('build/studio-dart-suite-evidence')..createSync(recursive: true);
  final scratch = evidence.createTempSync('run-').absolute;
  final raw = Directory('${scratch.path}/raw')..createSync();
  final report = File('${scratch.path}/tests.jsonl');
  final formatted = File('${scratch.path}/lcov.info');
  final runtimeRoot = Directory.systemTemp.createTempSync('.studio-dart-runtime-');
  final temp = Directory('${runtimeRoot.path}/.runtime')..createSync();
  try {
    stdout.writeln('Fresh Dart JSON and coverage evidence: ${scratch.path}');
    final tests = await Process.start(
      'dart',
      [
        '--suppress-analytics',
        'test',
        '-j1',
        '--exclude-tags',
        'ffmpeg || download || render || analysis || generative',
        '--coverage=${raw.path}',
        '--file-reporter',
        'json:${report.path}',
      ],
      environment: {'TMPDIR': temp.path},
      mode: ProcessStartMode.inheritStdio,
    );
    final testExit = await tests.exitCode;
    if (testExit != 0) {
      exitCode = testExit;
      return;
    }
    if (!report.existsSync() || !successfulTestRun(report.readAsStringSync())) {
      stderr.writeln('Dart suite did not produce fresh successful terminal JSON');
      exitCode = 1;
      return;
    }
    final formatter = await Process.start(
      'dart',
      [
        '--suppress-analytics',
        'run',
        'coverage:format_coverage',
        '--lcov',
        '--in=${raw.path}',
        '--out=${formatted.path}',
        '--report-on=lib',
      ],
      environment: {'TMPDIR': temp.path},
      mode: ProcessStartMode.inheritStdio,
    );
    final formatterExit = await formatter.exitCode;
    if (formatterExit != 0) {
      exitCode = formatterExit;
      return;
    }
    final coverage = mergeLineCoverage([formatted.readAsStringSync()]);
    final output = File('coverage/lcov.info');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(coverage);
  } on Object catch (error) {
    stderr.writeln('Dart coverage runner failed: $error');
    exitCode = 1;
  } finally {
    // Keep current reports; remove only this run's disposable external runtime.
    runtimeRoot.deleteSync(recursive: true);
  }
}
