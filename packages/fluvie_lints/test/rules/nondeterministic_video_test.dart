import 'package:fluvie_lints/src/rules/nondeterministic_video.dart';
import 'package:test/test.dart';

import 'lint_test_harness.dart';

void main() {
  test(
    'resolved clocks and unseeded random calls are reported; stable inputs are silent',
    () async {
      expect(
        await lintLinesFor(const NondeterministicVideo(), 'nondeterministic_video_fixture.dart'),
        [14, 15, 16, 17, 18],
      );
    },
  );
  test('application clocks, handlers and unrelated or unresolved types stay silent', () async {
    expect(
      await lintLinesFor(const NondeterministicVideo(), 'nondeterministic_video_safe_fixture.dart'),
      isEmpty,
    );
  });
}
