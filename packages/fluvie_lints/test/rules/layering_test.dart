import 'package:fluvie_lints/src/rules/layering.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = Layering();

  test('core may not import timing or feature layers', () async {
    final lines = await lintLinesFor(rule, 'src/core/layering_fixture.dart');
    expect(lines, [6, 9]);
  });

  test('a feature may not import diagnostics but may import core/timing', () async {
    final lines = await lintLinesFor(
      rule,
      'src/rendering/layering_feature_fixture.dart',
    );
    expect(lines, [7]);
  });

  test('the rule exposes no quick-fix', () {
    expect(rule.getFixes(), isEmpty);
  });
}
