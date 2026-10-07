import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('every publishable package carries the current workspace analysis policy', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'tool/sync_package_analysis.dart',
      '--check',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
