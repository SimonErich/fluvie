import 'package:fluvie_lints/src/rules/layering.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = Layering();

  test('core may not import timing or feature layers', () async {
    final lines = await lintLinesFor(rule, 'src/core/layering_fixture.dart');
    expect(lines, [6, 9, 12]);
  });

  test('a feature may not import diagnostics but may import core/timing', () async {
    final lines = await lintLinesFor(
      rule,
      'src/rendering/layering_feature_fixture.dart',
    );
    expect(lines, [7]);
  });

  test('timing may import core but not feature layers or diagnostics', () async {
    final lines = await lintLinesFor(rule, 'src/timing/layering_timing_fixture.dart');
    expect(lines, [7, 10]);
  });

  test('diagnostics sits at the top, so no import here is flagged', () async {
    final lines = await lintLinesFor(rule, 'src/diagnostics/layering_diagnostics_fixture.dart');
    expect(lines, isEmpty);
  });

  test('a file outside any src layer is left silent', () async {
    final lines = await lintLinesFor(rule, 'layering_toplevel_fixture.dart');
    expect(lines, isEmpty);
  });

  test('the rule exposes no quick-fix', () {
    expect(rule.getFixes(), isEmpty);
  });
}
