import 'dart:io';

import 'package:test/test.dart';

/// package:coverage's own marker grammar (util.dart): after the marker word,
/// only word characters, digits, and whitespace may follow to end-of-line.
/// Punctuation (a colon, a semicolon, a period) silently breaks the match —
/// and an unbalanced start/end pair makes `flutter test --coverage` throw a
/// FormatException at collection time. These mirrors keep every marker in the
/// charset both parsers accept.
final _start = RegExp(r'//\s*coverage:ignore-start[\w\d\s]*$');
final _end = RegExp(r'//\s*coverage:ignore-end[\w\d\s]*$');
final _line = RegExp(r'//\s*coverage:ignore-line[\w\d\s]*$');
final _file = RegExp(r'//\s*coverage:ignore-file[\w\d\s]*$');
final _anyMarker = RegExp('coverage:ignore-(start|end|line|file)');

void main() {
  test('every coverage:ignore marker parses under package:coverage', () {
    final problems = <String>[];
    final libFiles = Directory('packages')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && f.path.contains('/lib/'));
    for (final file in libFiles) {
      final lines = file.readAsLinesSync();
      var open = 0;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!_anyMarker.hasMatch(line)) continue;
        final loc = '${file.path}:${i + 1}';
        if (line.contains('coverage:ignore-start')) {
          if (!_start.hasMatch(line)) {
            problems.add('$loc ignore-start not collector-parsable: "$line"');
          } else {
            open++;
          }
        } else if (line.contains('coverage:ignore-end')) {
          if (!_end.hasMatch(line)) {
            problems.add('$loc ignore-end not collector-parsable: "$line"');
          } else {
            open--;
            if (open < 0) problems.add('$loc unmatched ignore-end');
          }
        } else if (line.contains('coverage:ignore-line')) {
          if (!_line.hasMatch(line)) {
            problems.add('$loc ignore-line not collector-parsable: "$line"');
          }
        } else if (line.contains('coverage:ignore-file')) {
          if (!_file.hasMatch(line)) {
            problems.add('$loc ignore-file not collector-parsable: "$line"');
          }
        }
      }
      if (open > 0) problems.add('${file.path}: $open unclosed ignore-start');
    }
    expect(
      problems,
      isEmpty,
      reason:
          'Marker reasons may use only letters, digits, and spaces — '
          'package:coverage drops the marker on any punctuation, and an '
          'unbalanced pair crashes flutter test --coverage.\n${problems.join('\n')}',
    );
  });
}
