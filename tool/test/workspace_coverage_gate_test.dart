import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('workspace coverage gates a newly declared production package', () async {
    final gate = File('tool/check_coverage.dart').absolute.path;
    final configuration = File('.dart_tool/package_config.json').absolute.path;
    final root = Directory.systemTemp.createTempSync('fluvie-coverage-contract-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync('workspace:\n  - packages/new_media\n');
    final package = Directory('${root.path}/packages/new_media')..createSync(recursive: true);
    File('${package.path}/pubspec.yaml').writeAsStringSync('name: new_media\n');
    Directory('${package.path}/lib').createSync();
    File('${package.path}/lib/api.dart').writeAsStringSync('int answer() => 42;\n');
    Directory('${package.path}/test').createSync();
    File('${package.path}/test/api_test.dart').writeAsStringSync('void main() {}\n');
    Directory('${package.path}/coverage').createSync();
    final coverage = File('${package.path}/coverage/lcov.info')
      ..writeAsStringSync('SF:lib/api.dart\nDA:1,0\nend_of_record\n');
    Future<ProcessResult> runGate() => Process.run(
      '${File(Platform.resolvedExecutable).parent.path}/dart',
      [
        '--suppress-analytics',
        'run',
        '--packages=$configuration',
        gate,
        '--workspace',
        '--min',
        '97',
      ],
      workingDirectory: root.path,
    );
    final failed = await runGate();
    expect(
      failed.exitCode,
      1,
      reason: 'new packages must not evade the gate\n${failed.stdout}\n${failed.stderr}',
    );
    expect(failed.stdout, contains('packages/new_media: FAIL 0.00% (0/1)'));

    coverage.writeAsStringSync('SF:lib/api.dart\nDA:1,1\nend_of_record\n');
    final passed = await runGate();
    expect(passed.exitCode, 0, reason: '${passed.stdout}\n${passed.stderr}');
    expect(passed.stdout, contains('packages/new_media: ok   100.00% (1/1)'));
  });
}
