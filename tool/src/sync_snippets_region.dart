import 'dart:io';

/// Reads the source at `relPath` (resolved against [root]) and returns the lines
/// between the `// #docregion <region>` and `// #enddocregion <region>` markers.
///
/// The marker lines, any nested `#docregion` markers, and any `// ignore:` /
/// `// ignore_for_file:` lines are dropped; the common leading indentation is
/// stripped and blank lines padding the region are trimmed. Returns null and
/// records a hard error in [errors] on any failure (missing file, missing or
/// unterminated region).
List<String>? extractRegion(String root, String relPath, String region, List<String> errors) {
  final file = File('$root/$relPath');
  if (!file.existsSync()) {
    errors.add('source not found: $relPath (referenced by a code-excerpt directive).');
    return null;
  }
  final src = file.readAsStringSync().split('\n');
  final start = _markerIndex(src, 'docregion', region);
  if (start == null) {
    errors.add('region "$region" not found in $relPath.');
    return null;
  }
  final end = _markerIndex(src, 'enddocregion', region);
  if (end == null || end <= start) {
    errors.add('region "$region" in $relPath is not terminated with // #enddocregion $region.');
    return null;
  }

  final raw = src
      .sublist(start + 1, end)
      .where((l) => !_isIgnoreComment(l) && !_isRegionMarker(l))
      .toList();
  return _stripCommonIndent(_trimBlankEdges(raw));
}

int? _markerIndex(List<String> src, String marker, String region) {
  final re = RegExp('^\\s*//\\s*#$marker\\s+${RegExp.escape(region)}\\s*\$');
  for (var i = 0; i < src.length; i++) {
    if (re.hasMatch(src[i])) return i;
  }
  return null;
}

/// True for a nested `// #docregion <name>` / `// #enddocregion <name>` marker
/// line, so an inner region's markers never leak into the outer fence.
bool _isRegionMarker(String line) {
  final t = line.trimLeft();
  return t.startsWith('// #docregion') || t.startsWith('// #enddocregion');
}

bool _isIgnoreComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('// ignore:') || t.startsWith('// ignore_for_file:');
}

/// Drops blank lines at the start and end of a region so padding around the
/// `#docregion` markers never lands inside a fence.
List<String> _trimBlankEdges(List<String> lines) {
  var start = 0;
  var end = lines.length;
  while (start < end && lines[start].trim().isEmpty) {
    start++;
  }
  while (end > start && lines[end - 1].trim().isEmpty) {
    end--;
  }
  return lines.sublist(start, end);
}

List<String> _stripCommonIndent(List<String> lines) {
  final nonBlank = lines.where((l) => l.trim().isNotEmpty);
  if (nonBlank.isEmpty) return lines;
  final indent = nonBlank
      .map((l) => l.length - l.trimLeft().length)
      .reduce((a, b) => a < b ? a : b);
  if (indent == 0) return lines;
  return lines.map((l) => l.trim().isEmpty ? l : l.substring(indent)).toList();
}
