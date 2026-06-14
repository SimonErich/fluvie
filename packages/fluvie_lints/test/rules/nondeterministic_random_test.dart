import 'package:fluvie_lints/src/rules/nondeterministic_random.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = NondeterministicRandom();

  test('flags unseeded Random() and DateTime.now() only', () async {
    final lines = await lintLinesFor(
      rule,
      'nondeterministic_random_fixture.dart',
    );
    // Line 8: Random(); line 11: DateTime.now(). Seeded Random(42) on 14 and
    // Random.secure() on 17 are allowed.
    expect(lines, [8, 11]);
  });

  test('the rule exposes no quick-fix', () {
    expect(rule.getFixes(), isEmpty);
  });
}
