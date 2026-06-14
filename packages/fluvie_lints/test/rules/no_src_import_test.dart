import 'package:fluvie_lints/src/rules/no_src_import.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = NoSrcImport();

  test('flags a cross-package src import and nothing else', () async {
    final lines = await lintLinesFor(rule, 'lib/no_src_import_fixture.dart');
    expect(lines, [7]);
  });

  test('allows a same-package src import, flags a cross-package one', () async {
    final lines = await lintLinesFor(
      rule,
      'lib/no_src_import_samepkg_fixture.dart',
    );
    // The package:fixtures/src import (line 7) is the file's own package; only
    // the package:fluvie/src import (line 10) trips.
    expect(lines, [10]);
  });

  test('does not flag a cross-package src import in a test file', () async {
    final lines = await lintLinesFor(rule, 'no_src_import_test_file_fixture.dart');
    expect(lines, isEmpty);
  });

  test('the quick-fix rewrites the import to the public barrel', () async {
    final fixed = await applyFixTo(
      rule,
      rule.getFixes().single,
      'lib/no_src_import_fixture.dart',
    );
    expect(fixed, contains("import 'package:fluvie/fluvie.dart';"));
    expect(fixed, isNot(contains('package:fluvie/src/core/time.dart')));
  });
}
