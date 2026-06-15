import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('ProcessRunResult', () {
    test('is a plain value carrier', () {
      const result = ProcessRunResult(exitCode: 0, stdout: 'out', stderr: 'err');
      expect(result.exitCode, 0);
      expect(result.stdout, 'out');
      expect(result.stderr, 'err');
    });
  });

  group('IoProcessRunner', () {
    // Under `flutter test` the VM executable is flutter_tester, which cannot
    // re-run itself, so these cases use POSIX coreutils (uname/pwd/false) —
    // present on the Linux baseline and macOS alike.
    test('runs uname: exit 0 and non-empty stdout', () async {
      final result = await const IoProcessRunner().run('uname', const []);
      expect(result.exitCode, 0);
      expect(result.stdout.trim(), isNotEmpty);
    });

    test('honors workingDirectory (pwd prints the temp dir)', () async {
      final tempDir = await Directory.systemTemp.createTemp('fluvie_runner_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final result = await const IoProcessRunner().run(
        'pwd',
        const [],
        workingDirectory: tempDir.path,
      );
      expect(result.exitCode, 0);
      expect(result.stdout.trim(), tempDir.resolveSymbolicLinksSync());
    });

    test('reports a non-zero exit code without throwing', () async {
      final result = await const IoProcessRunner().run('false', const []);
      expect(result.exitCode, isNot(0));
    });
  });

  group('processRunnerProvider', () {
    test('resolves to IoProcessRunner by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(processRunnerProvider), isA<IoProcessRunner>());
    });
  });
}
