import 'package:fluvie_lints/src/rules/conflicting_keyframe_fields.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = ConflictingKeyframeFields();

  test('flags two full-window writes of the same field', () async {
    final lines = await lintLinesFor(
      rule,
      'conflicting_keyframe_fields_fixture.dart',
    );
    // Lines 28 and 29: both write opacity over the default window. The
    // different-field and explicit-at: cases stay silent.
    expect(lines, [28, 29]);
  });

  test('the rule exposes no quick-fix', () {
    expect(rule.getFixes(), isEmpty);
  });
}
