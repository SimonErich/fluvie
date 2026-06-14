import 'package:fluvie_lints/src/rules/relative_outside_scope.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = RelativeOutsideScope();

  test('flags relative Scene/Video durations only', () async {
    final lines = await lintLinesFor(rule, 'relative_outside_scope_fixture.dart');
    // Line 28: Scene(duration: 0.5.relative). Line 37: the Time.relative(...)
    // constructor form. The concrete duration and the element-scoped relative
    // stay silent.
    expect(lines, [28, 37]);
  });

  test('the rule exposes no quick-fix', () {
    expect(rule.getFixes(), isEmpty);
  });
}
