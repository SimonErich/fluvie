// The golden-comment harness: run `dart run custom_lint` over this fixture
// project and assert it is green. custom_lint enforces every expect_lint
// marker (each must fire) and rejects any unexpected lint, so a green run
// proves every rule fires exactly once on real fluvie syntax and nothing else
// leaks. This is the true-positive half of the lints seam; melos run lint
// staying green on the real packages is the zero-false-positive half.
@Tags(['lint'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every rule fixture fulfils its // expect_lint marker',
    () async {
      final result = await Process.run('dart', [
        'run',
        'custom_lint',
      ], workingDirectory: Directory.current.path);
      expect(
        result.exitCode,
        0,
        reason:
            'custom_lint failed on the fixtures:\n'
            '${result.stdout}\n${result.stderr}',
      );
      expect(result.stdout, contains('No issues found!'));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
