import 'package:fluvie_lints/src/rules/dangling_anchor.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = DanglingAnchor();

  test('flags a triggered-but-unattached local anchor only', () async {
    final lines = await lintLinesFor(rule, 'dangling_anchor_fixture.dart');
    // Line 23: Trigger.whenEnds(ghost). The intro anchor is attached, so its
    // Trigger.whenStarts is fine.
    expect(lines, [23]);
  });

  test('the rule exposes no quick-fix', () {
    expect(rule.getFixes(), isEmpty);
  });
}
