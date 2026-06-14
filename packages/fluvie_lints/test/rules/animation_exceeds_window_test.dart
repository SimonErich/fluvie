import 'package:fluvie_lints/src/rules/animation_exceeds_window.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  const rule = AnimationExceedsWindow();

  test('flags only a same-unit duration longer than its window', () async {
    final lines = await lintLinesFor(
      rule,
      'animation_exceeds_window_fixture.dart',
    );
    // Line 29: 90.frames over a 60-frame window. Line 47: 2.5s over a 1.0s
    // window (double literals). The 30-frame fit and the mixed-unit case stay
    // silent.
    expect(lines, [29, 47]);
  });

  test('the rule exposes no quick-fix', () {
    expect(rule.getFixes(), isEmpty);
  });
}
