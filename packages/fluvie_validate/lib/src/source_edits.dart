import 'dart:convert';

/// Applies a bounded JSON patch against the original text, preserving all other
/// bytes. Each `before` must occur exactly once, and ranges must not overlap.
/// Source, reply and resulting text each accept at most 256 KiB of UTF-8.
String applyDartSourceEdits(String source, String reply) {
  const limit = 256 * 1024;
  if (utf8.encode(source).length > limit) {
    throw const SourceEditException('Dart source exceeds the 256 KiB limit.');
  }
  if (utf8.encode(reply).length > limit) {
    throw const SourceEditException('Dart edit reply exceeds the 256 KiB limit.');
  }
  var text = reply.trim();
  final fence = RegExp(r'^```(?:json)?\s*\n([\s\S]*?)\n```$').firstMatch(text);
  if (fence != null) text = fence.group(1)!;
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const SourceEditException('Dart edits must be a JSON object containing an edits array.');
  }
  if (json is! Map<String, Object?> || json.length != 1 || json['edits'] is! List<Object?>) {
    throw const SourceEditException('Dart edits must contain only an edits array.');
  }
  final edits = json['edits']! as List<Object?>;
  if (edits.isEmpty || edits.length > 32) {
    throw const SourceEditException('Dart edits must contain 1..32 replacements.');
  }
  final replacements = <({int start, int end, String after})>[];
  for (final edit in edits) {
    if (edit is! Map<String, Object?> ||
        edit.length != 2 ||
        edit['before'] is! String ||
        edit['after'] is! String) {
      throw const SourceEditException('Each Dart edit must contain only before and after strings.');
    }
    final before = edit['before']! as String;
    final after = edit['after']! as String;
    final start = source.indexOf(before);
    if (before.isEmpty || start < 0 || source.indexOf(before, start + 1) >= 0) {
      final preview = jsonEncode(before.length > 96 ? '${before.substring(0, 96)}…' : before);
      final matches = before.isEmpty
          ? 'empty text'
          : start < 0
          ? 'no match'
          : 'multiple matches';
      throw SourceEditException(
        'Each Dart edit must match exactly one non-empty original range. '
        'Found $matches for $preview. Include surrounding Dart to identify the intended range.',
      );
    }
    replacements.add((start: start, end: start + before.length, after: after));
  }
  replacements.sort((a, b) => a.start.compareTo(b.start));
  for (var index = 1; index < replacements.length; index++) {
    if (replacements[index].start < replacements[index - 1].end) {
      throw const SourceEditException('Dart edit ranges overlap.');
    }
  }
  var result = source;
  for (final edit in replacements.reversed) {
    result = result.replaceRange(edit.start, edit.end, edit.after);
  }
  if (utf8.encode(result).length > limit) {
    throw const SourceEditException('Edited Dart source exceeds the 256 KiB limit.');
  }
  return result;
}

/// A reply cannot be applied without ambiguous or overlapping source changes.
final class SourceEditException implements Exception {
  /// Creates a precise patch-validation failure.
  const SourceEditException(this.message);

  /// Reason the original source cannot safely accept the requested edits.
  final String message;

  @override
  String toString() => message;
}
