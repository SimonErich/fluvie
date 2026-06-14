import 'package:fluvie_lints/src/rules/cyclic_trigger.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = CyclicTrigger();

  test('flags both members of a two-node cycle, not an acyclic edge', () async {
    final lines = await lintLinesFor(rule, 'cyclic_trigger_fixture.dart');
    // Lines 29 and 30 are the two .animate calls forming a <-> b. The c edge on
    // line 33 is acyclic.
    expect(lines, [29, 30]);
  });

  test('the rule exposes no quick-fix', () {
    expect(rule.getFixes(), isEmpty);
  });
}
