import 'package:test/test.dart';

import '../check_editor_performance.dart';

void main() {
  test('each actual mode must match the requested build and assertion state', () {
    for (final requested in ['debug', 'profile', 'release']) {
      for (final actual in ['debug', 'profile', 'release']) {
        final problems = performanceModeProblems(requested, {
          'mode': actual,
          'assertionsEnabled': actual == 'debug',
        });
        expect(problems.isEmpty, requested == actual);
      }
    }
  });

  test('missing fields and falsely enabled or disabled assertions are rejected', () {
    expect(performanceModeProblems('release', {}), isNotEmpty);
    expect(
      performanceModeProblems('release', {'mode': 'release', 'assertionsEnabled': true}),
      isNotEmpty,
    );
    expect(
      performanceModeProblems('debug', {'mode': 'debug', 'assertionsEnabled': false}),
      isNotEmpty,
    );
    expect(
      performanceModeProblems('optimized', {'mode': 'optimized', 'assertionsEnabled': false}),
      isNotEmpty,
    );
  });
}
