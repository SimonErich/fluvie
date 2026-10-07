import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Creates compiler scratch space excluded from repository formatter discovery.
Directory createFlutterRuntimeDirectory(Directory run) =>
    Directory('${run.path}/.runtime')..createSync();

/// Mirrors Flutter discovery: recurse real directories and accept file links.
List<String> discoverFlutterTests(Directory directory) => directory
    .listSync(recursive: true, followLinks: false)
    .where((entry) => entry.path.endsWith('_test.dart') && FileSystemEntity.isFileSync(entry.path))
    .map((entry) => entry.path)
    .toList();

/// Proves that a fresh JSON test report ended successfully, not just exit zero.
bool successfulTestRun(String report) {
  try {
    final events = report
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map(jsonDecode)
        .toList();
    if (events.isEmpty || events.any((event) => event is! Map<String, Object?>)) return false;
    final records = events.cast<Map<String, Object?>>();
    return records.last['type'] == 'done' &&
        records.last['success'] == true &&
        records.where((event) => event['type'] == 'done').length == 1 &&
        !records.any((event) => event['type'] == 'error');
  } on FormatException {
    return false;
  }
}

/// Partitions every test exactly once, without changing the discovery manifest.
List<List<String>> flutterSuiteBatches(List<String> files, {int maxFiles = 120}) {
  if (maxFiles <= 0 || files.any((file) => file.isEmpty) || files.toSet().length != files.length) {
    throw ArgumentError('Batch size must be positive and test paths nonempty and unique');
  }
  final sorted = files.toList()..sort();
  return [
    for (var i = 0; i < sorted.length; i += maxFiles)
      sorted.sublist(i, math.min(i + maxFiles, sorted.length)),
  ];
}

/// Runs every batch, retaining failures and publishing only complete coverage.
///
/// [coveragePath] must identify fresh per-batch artifacts. [read] returns null
/// for absent reports. A completed empty report contributes no executable lines,
/// not fabricated coverage. No old package report is used as a merge input.
Future<int> executeFlutterBatches({
  required List<List<String>> batches,
  required List<String> arguments,
  required Future<int> Function(List<String>) run,
  required Future<bool> Function(int) verify,
  required String Function(int) coveragePath,
  required Future<String?> Function(String) read,
  required Future<void> Function(String) write,
}) async {
  if (batches.isEmpty || batches.any((batch) => batch.isEmpty)) {
    throw ArgumentError('A batch plan must contain tests');
  }
  final coverage = arguments.contains('--coverage');
  final reports = <String>[];
  var result = 0;
  var verified = true;
  for (var index = 0; index < batches.length; index++) {
    final path = coverage ? coveragePath(index) : null;
    final code = await run([
      'test',
      ...batches[index],
      ...arguments,
      if (path != null) ...['--coverage-path', path],
    ]);
    if (code != 0 && result == 0) result = code;
    if (!await verify(index)) {
      verified = false;
      if (result == 0) result = 1;
    }
    if (path != null) {
      final report = await read(path);
      if (report != null) {
        reports.add(report);
      } else if (result == 0) {
        result = 1;
      }
    }
  }
  if (coverage && result == 0 && verified && reports.length == batches.length) {
    final nonempty = reports.where((report) => report.isNotEmpty).toList();
    await write(nonempty.isEmpty ? '' : mergeLineCoverage(nonempty));
  }
  return result;
}

/// Merges Flutter line-only LCOV reports, summing hits and recomputing totals.
///
/// Malformed records and unsupported branch/function/checksum data fail rather
/// than silently weakening coverage. Each report must contain a source record.
String mergeLineCoverage(Iterable<String> reports) {
  final sources = <String, Map<int, int>>{};
  var reportCount = 0;
  for (final report in reports) {
    reportCount++;
    String? source;
    var hasSource = false;
    for (final line in report.split('\n')) {
      if (line.isEmpty || line.startsWith('TN:')) continue;
      if (line.startsWith('SF:')) {
        if (source != null || line.length == 3) {
          throw const FormatException('Invalid source record');
        }
        source = line.substring(3);
        sources.putIfAbsent(source, () => {});
        hasSource = true;
      } else if (line.startsWith('DA:')) {
        final values = line.substring(3).split(',');
        if (source == null || values.length != 2) {
          throw const FormatException('Invalid line record');
        }
        final number = int.tryParse(values[0]);
        final hits = int.tryParse(values[1]);
        if (number == null || number <= 0 || hits == null || hits < 0) {
          throw const FormatException('Invalid line number or hit count');
        }
        sources[source]!.update(number, (previous) => previous + hits, ifAbsent: () => hits);
      } else if (line == 'end_of_record') {
        if (source == null) throw const FormatException('Record without source');
        source = null;
      } else if (!line.startsWith('LF:') && !line.startsWith('LH:')) {
        throw FormatException('Unsupported coverage record: $line');
      }
    }
    if (source != null || !hasSource) throw const FormatException('Incomplete coverage report');
  }
  if (reportCount == 0) throw const FormatException('No coverage reports');
  final output = StringBuffer();
  for (final source in sources.keys.toList()..sort()) {
    final lines = sources[source]!;
    output.writeln('SF:$source');
    for (final number in lines.keys.toList()..sort()) {
      output.writeln('DA:$number,${lines[number]}');
    }
    output
      ..writeln('LF:${lines.length}')
      ..writeln('LH:${lines.values.where((hits) => hits > 0).length}')
      ..writeln('end_of_record');
  }
  return output.toString();
}
