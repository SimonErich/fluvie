/// Pure lcov parsing and aggregation for the coverage gate
/// (`tool/check_coverage.dart`). No IO here so it stays unit-testable.
library;

/// Line-coverage totals for one source file in an lcov report.
class FileCoverage {
  /// Creates the summary for [path].
  const FileCoverage({
    required this.path,
    required this.linesHit,
    required this.linesFound,
  });

  /// Source path as recorded by the `SF:` line.
  final String path;

  /// Lines executed at least once (`LH:`, or counted from `DA:` entries).
  final int linesHit;

  /// Coverable lines (`LF:`, or counted from `DA:` entries).
  final int linesFound;
}

/// Generated-file suffixes excluded from the gate by default.
const List<String> defaultExcludedSuffixes = [
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
];

/// Parses lcov [text] into one [FileCoverage] per `SF:` record.
///
/// Prefers the `LH:`/`LF:` totals; falls back to counting `DA:` lines when a
/// record carries no totals.
///
/// When [ignoresFor] is supplied it returns the 1-based source lines a file
/// marks with a `// coverage:ignore` comment (see [ignoredLines]); those lines
/// are dropped from the file's hit/found counts, recomputed from the `DA:`
/// records (the `LH:`/`LF:` totals are ignored for that file because they
/// predate the strip). A file with no ignored lines keeps the fast `LH:`/`LF:`
/// path. This is how the gate honors the documented ignore policy uniformly
/// across both the Flutter (`flutter test --coverage`) and pure-Dart
/// (`format_coverage`) lcov producers, neither of which strips on its own.
List<FileCoverage> parseLcov(String text, {Set<int> Function(String path)? ignoresFor}) {
  final files = <FileCoverage>[];
  String? path;
  int? lh;
  int? lf;
  var daHit = 0;
  var daFound = 0;
  var ignoredHit = 0;
  var ignoredFound = 0;

  void close() {
    if (path == null) return;
    final ignored = ignoresFor?.call(path!) ?? const <int>{};
    if (ignored.isEmpty) {
      files.add(FileCoverage(path: path!, linesHit: lh ?? daHit, linesFound: lf ?? daFound));
    } else {
      // Some coverable lines are ignored: recount from DA, dropping them, and
      // disregard the now-stale LH/LF totals.
      files.add(
        FileCoverage(
          path: path!,
          linesHit: daHit - ignoredHit,
          linesFound: daFound - ignoredFound,
        ),
      );
    }
    path = null;
    lh = null;
    lf = null;
    daHit = 0;
    daFound = 0;
    ignoredHit = 0;
    ignoredFound = 0;
  }

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      close();
      path = line.substring(3);
    } else if (line.startsWith('LH:')) {
      lh = int.parse(line.substring(3));
    } else if (line.startsWith('LF:')) {
      lf = int.parse(line.substring(3));
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final lineNo = int.parse(parts[0]);
      final hits = int.parse(parts[1]);
      daFound += 1;
      if (hits > 0) daHit += 1;
      final ignored = ignoresFor?.call(path!) ?? const <int>{};
      if (ignored.contains(lineNo)) {
        ignoredFound += 1;
        if (hits > 0) ignoredHit += 1;
      }
    } else if (line == 'end_of_record') {
      close();
    }
  }
  close();
  return files;
}

/// The 1-based source lines [source] marks as coverage-ignored.
///
/// Honors the project convention (a free-text reason may follow the marker on
/// the same line, unlike `package:coverage`'s stricter matcher):
///
/// * `// coverage:ignore-file` — every line (the whole file is excluded).
/// * `// coverage:ignore-line` — the line the comment sits on. When the marker
///   is the only thing on its line (a comment placed *above* the code, which is
///   the natural placement that `dart format` preserves for a multi-line
///   declaration), it also covers the next non-blank line. A trailing marker
///   (code then `// coverage:ignore-line`) only covers its own line.
/// * `// coverage:ignore-start` … `// coverage:ignore-end` — the inclusive
///   block between the two markers.
///
/// An unbalanced `ignore-start` runs to the end of the file. The returned set
/// is the union of all three; callers intersect it with the `DA:` line set.
Set<int> ignoredLines(String source) {
  final lines = source.split('\n');
  final ignored = <int>{};
  var inBlock = false;
  for (var i = 0; i < lines.length; i++) {
    final text = lines[i];
    final lineNo = i + 1;
    if (_ignoreFile.hasMatch(text)) {
      return {for (var n = 1; n <= lines.length; n++) n};
    }
    final hasStart = _ignoreStart.hasMatch(text);
    final hasEnd = _ignoreEnd.hasMatch(text);
    if (hasStart && hasEnd) {
      // A start and end on one line is a closed, single-line ignore: never
      // leave the block open to the end of the file.
      ignored.add(lineNo);
      continue;
    }
    if (hasStart) {
      inBlock = true;
      ignored.add(lineNo);
      continue;
    }
    if (hasEnd) {
      inBlock = false;
      ignored.add(lineNo);
      continue;
    }
    if (inBlock) {
      ignored.add(lineNo);
      continue;
    }
    if (_ignoreLine.hasMatch(text)) {
      ignored.add(lineNo);
      // A marker alone on its line also ignores the next non-blank line, so a
      // comment placed above a multi-line declaration covers that declaration.
      if (_isCommentOnly(text)) {
        for (var j = i + 1; j < lines.length; j++) {
          if (lines[j].trim().isEmpty) continue;
          ignored.add(j + 1);
          break;
        }
      }
    }
  }
  return ignored;
}

/// Whether [line] is a comment-only line (its first non-blank character starts
/// a `//` comment), as opposed to a trailing comment after code.
bool _isCommentOnly(String line) => line.trimLeft().startsWith('//');

final RegExp _ignoreFile = RegExp(r'//\s*coverage:ignore-file\b');
final RegExp _ignoreStart = RegExp(r'//\s*coverage:ignore-start\b');
final RegExp _ignoreEnd = RegExp(r'//\s*coverage:ignore-end\b');
final RegExp _ignoreLine = RegExp(r'//\s*coverage:ignore-line\b');

/// Sums hit/found lines across [files], skipping paths ending in any of
/// [excludedSuffixes].
({int hit, int found}) aggregate(
  Iterable<FileCoverage> files, {
  List<String> excludedSuffixes = defaultExcludedSuffixes,
}) {
  var hit = 0;
  var found = 0;
  for (final f in files) {
    if (excludedSuffixes.any(f.path.endsWith)) continue;
    hit += f.linesHit;
    found += f.linesFound;
  }
  return (hit: hit, found: found);
}

/// Line coverage as a percentage; zero coverable lines count as fully covered
/// (the empty-skeleton case).
double percent(({int hit, int found}) total) =>
    total.found == 0 ? 100.0 : total.hit / total.found * 100;
