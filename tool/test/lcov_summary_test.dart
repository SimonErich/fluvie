import 'package:test/test.dart';

import '../src/lcov_summary.dart';

const _record = '''
SF:lib/src/a.dart
DA:1,2
DA:2,0
DA:3,1
LH:2
LF:3
end_of_record
SF:lib/src/b.g.dart
DA:1,0
LH:0
LF:1
end_of_record
''';

const _recordWithoutTotals = '''
SF:lib/src/c.dart
DA:1,1
DA:2,0
end_of_record
''';

void main() {
  group('parseLcov', () {
    test('reads one summary per SF record using LH/LF', () {
      final files = parseLcov(_record);

      expect(files, hasLength(2));
      expect(files.first.path, 'lib/src/a.dart');
      expect(files.first.linesHit, 2);
      expect(files.first.linesFound, 3);
    });

    test('falls back to DA lines when LH/LF are absent', () {
      final files = parseLcov(_recordWithoutTotals);

      expect(files.single.linesHit, 1);
      expect(files.single.linesFound, 2);
    });

    test('returns nothing for empty input', () {
      expect(parseLcov(''), isEmpty);
    });
  });

  group('aggregate', () {
    test('sums hits and founds, skipping generated files', () {
      final total = aggregate(parseLcov(_record));

      expect(total.hit, 2);
      expect(total.found, 3);
    });

    test('keeps generated files when no suffix is excluded', () {
      final total = aggregate(parseLcov(_record), excludedSuffixes: []);

      expect(total.hit, 2);
      expect(total.found, 4);
    });
  });

  group('percent', () {
    test('is hit over found', () {
      expect(percent((hit: 19, found: 20)), closeTo(95.0, 1e-9));
    });

    test('treats zero coverable lines as fully covered', () {
      expect(percent((hit: 0, found: 0)), 100.0);
    });
  });

  group('ignoredLines', () {
    test('a trailing ignore-line marks only its own line', () {
      const src = 'a;\nb; // coverage:ignore-line — defensive, unreachable\nc;';
      expect(ignoredLines(src), {2});
    });

    test('a standalone ignore-line also marks the next non-blank line', () {
      // The natural placement: the marker sits above a multi-line declaration
      // that dart format would otherwise split off from a trailing comment.
      const src = '1;\n// coverage:ignore-line: const-ctor artifact\nconst Foo({\n';
      expect(ignoredLines(src), {2, 3});
    });

    test('a standalone ignore-line skips blanks to reach the next code line', () {
      const src = '// coverage:ignore-line: glue\n\n  realCode();';
      expect(ignoredLines(src), {1, 3});
    });

    test('marks an inclusive ignore-start..ignore-end block', () {
      const src = '1;\n// coverage:ignore-start glue\n3;\n4;\n// coverage:ignore-end\n6;';
      expect(ignoredLines(src), {2, 3, 4, 5});
    });

    test('an unbalanced ignore-start runs to the end of the file', () {
      const src = '1;\n// coverage:ignore-start\n3;\n4;';
      expect(ignoredLines(src), {2, 3, 4});
    });

    test('a start and end on one line is a closed single-line ignore', () {
      const src = '1;\n// coverage:ignore-start // coverage:ignore-end\n3;\n4;';
      expect(ignoredLines(src), {2}, reason: 'must not open a block to EOF');
    });

    test('ignore-file marks every line', () {
      const src = '// coverage:ignore-file thin platform bridge\nx;\ny;';
      expect(ignoredLines(src), {1, 2, 3});
    });

    test('a file with no markers ignores nothing', () {
      expect(ignoredLines('a;\nb;\nc;'), isEmpty);
    });
  });

  group('parseLcov honors ignored lines', () {
    const lcov = '''
SF:lib/src/a.dart
DA:1,2
DA:2,0
DA:3,0
DA:4,5
LH:2
LF:4
end_of_record
''';

    test('drops an ignored uncovered line from the found/hit counts', () {
      // Line 2 is uncovered (DA:2,0) and ignored → both found and hit shrink by
      // its contribution (found 4→3, hit unchanged since it was a miss).
      final files = parseLcov(lcov, ignoresFor: (_) => {2});
      expect(files.single.linesFound, 3);
      expect(files.single.linesHit, 2);
    });

    test('an ignored covered line shrinks both hit and found', () {
      final files = parseLcov(lcov, ignoresFor: (_) => {4});
      expect(files.single.linesFound, 3);
      expect(files.single.linesHit, 1);
    });

    test('no ignores keeps the fast LH/LF path', () {
      final files = parseLcov(lcov, ignoresFor: (_) => const {});
      expect(files.single.linesFound, 4);
      expect(files.single.linesHit, 2);
    });

    test('ignoring an uncovered line lifts the computed percentage', () {
      final raw = percent(aggregate(parseLcov(lcov)));
      final stripped = percent(aggregate(parseLcov(lcov, ignoresFor: (_) => {2, 3})));
      expect(raw, closeTo(50.0, 1e-9)); // 2/4
      expect(stripped, closeTo(100.0, 1e-9)); // 2/2 after dropping the two misses
    });
  });
}
