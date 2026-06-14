import 'package:fluvie_lints/src/rules/deprecated_member.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = DeprecatedMember();

  test('flags each consolidated name, never a current one', () async {
    final lines = await lintLinesFor(rule, 'deprecated_member_fixture.dart');
    // Lines 8 (VStack), 11 (EmbeddedVideo), 14 (KenBurnsImage). Stack on 17 is
    // current and is not flagged.
    expect(lines, [8, 11, 14]);
  });

  test('the quick-fix renames the type to its 1.0 name', () async {
    final fixed = await applyFixTo(
      rule,
      rule.getFixes().single,
      'deprecated_member_one_fixture.dart',
    );
    expect(fixed, contains('Stack? a;'));
    expect(fixed, isNot(contains('VStack')));
  });
}
