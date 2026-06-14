import 'dart:io';

import 'src/lcov_summary.dart';

/// The coverage gate: `dart tool/check_coverage.dart --min 95 <pkg dirs...>`.
///
/// Reads `<pkg>/coverage/lcov.info` for every package directory given,
/// excludes generated files, and fails (exit 1) when any package falls below
/// the minimum line-coverage percentage. Zero coverable lines pass with a
/// notice (the empty-skeleton case); a missing report for a package that has
/// Dart sources under `lib/` fails.
Future<void> main(List<String> args) async {
  var min = 95.0;
  final dirs = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--min') {
      min = double.parse(args[++i]);
    } else {
      dirs.add(args[i]);
    }
  }
  if (dirs.isEmpty) {
    stderr.writeln('usage: dart tool/check_coverage.dart --min <pct> <package dirs...>');
    exitCode = 64;
    return;
  }

  var failed = false;
  stdout.writeln('coverage gate (min ${min.toStringAsFixed(0)}%):');
  for (final dir in dirs) {
    final lcov = File('$dir/coverage/lcov.info');
    if (!lcov.existsSync()) {
      if (_hasDartSources('$dir/lib')) {
        stdout.writeln('  $dir: FAIL (no coverage/lcov.info; run `melos run coverage` first)');
        failed = true;
      } else {
        stdout.writeln('  $dir: pass (no Dart sources)');
      }
      continue;
    }
    final total = aggregate(parseLcov(lcov.readAsStringSync(), ignoresFor: _ignoresFor(dir)));
    final pct = percent(total);
    if (total.found == 0) {
      stdout.writeln('  $dir: pass (no coverable lines yet)');
    } else if (pct < min) {
      stdout.writeln('  $dir: FAIL ${pct.toStringAsFixed(2)}% (${total.hit}/${total.found})');
      failed = true;
    } else {
      stdout.writeln('  $dir: ok   ${pct.toStringAsFixed(2)}% (${total.hit}/${total.found})');
    }
  }
  if (failed) exitCode = 1;
}

bool _hasDartSources(String libDir) {
  final dir = Directory(libDir);
  if (!dir.existsSync()) return false;
  return dir.listSync(recursive: true).whereType<File>().any((f) => f.path.endsWith('.dart'));
}

/// A per-package resolver of a source file's `// coverage:ignore` lines.
///
/// The lcov `SF:` path is relative (`lib/...`, the Flutter producer) or
/// absolute (the `format_coverage` producer); both are resolved against the
/// package [dir]. Results are memoized so a file is read and scanned once. A
/// missing source yields no ignores (the strip is best-effort: a stale report
/// never crashes the gate).
Set<int> Function(String) _ignoresFor(String dir) {
  final cache = <String, Set<int>>{};
  return (String sfPath) {
    return cache.putIfAbsent(sfPath, () {
      final file = sfPath.startsWith('/') ? File(sfPath) : File('$dir/$sfPath');
      if (!file.existsSync()) return const <int>{};
      return ignoredLines(file.readAsStringSync());
    });
  };
}
