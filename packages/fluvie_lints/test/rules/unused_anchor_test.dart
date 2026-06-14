import 'package:fluvie_lints/src/rules/unused_anchor.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = UnusedAnchor();

  test('flags a local orphan, never a referenced anchor or a class field', () async {
    final lines = await lintLinesFor(rule, 'unused_anchor_fixture.dart');
    // Line 22: the local orphan. The intro anchor is used by a Trigger, and the
    // class field (line 17) is skipped because a field may be used elsewhere.
    expect(lines, [22]);
  });

  test('the quick-fix removes the unused local declaration', () async {
    final fixed = await applyFixTo(
      rule,
      rule.getFixes().single,
      'unused_anchor_fixture.dart',
    );
    expect(fixed, isNot(contains("Anchor('orphan')")));
    expect(fixed, contains("Anchor('intro')"));
  });

  test('flags a top-level orphan and the fix removes it', () async {
    final lines = await lintLinesFor(rule, 'unused_anchor_toplevel_fixture.dart');
    expect(lines, [10]);
    final fixed = await applyFixTo(
      rule,
      rule.getFixes().single,
      'unused_anchor_toplevel_fixture.dart',
    );
    expect(fixed, isNot(contains("Anchor('topOrphan')")));
  });
}
