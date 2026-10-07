import 'dart:io';

import 'package:test/test.dart';

import '../src/flutter_suite_batches.dart';

void main() {
  test('compiler runtime does not contaminate repository formatter discovery', () async {
    final fixture = Directory.systemTemp.createTempSync('studio_formatter_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final runtime = createFlutterRuntimeDirectory(fixture);
    File('${runtime.path}/listener.dart').writeAsStringSync('void main(){final x=1;}');
    File('${fixture.path}/ready.dart').writeAsStringSync('void main() {}\n');
    final formatter = await Process.run(Platform.resolvedExecutable, [
      '--suppress-analytics',
      'format',
      '--output=none',
      '--set-exit-if-changed',
      fixture.path,
    ]);
    expect(formatter.exitCode, 0, reason: '${formatter.stdout}\n${formatter.stderr}');
  });

  test('real discovery matches Flutter including file links but not directory links', () {
    final fixture = Directory.systemTemp.createTempSync('studio_discovery_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final tests = Directory('${fixture.path}/test')..createSync();
    final nested = Directory('${tests.path}/nested')..createSync();
    final outside = Directory('${fixture.path}/outside')..createSync();
    File('${tests.path}/real_test.dart').writeAsStringSync('');
    File('${tests.path}/ignored.dart').writeAsStringSync('');
    File('${nested.path}/nested_test.dart').writeAsStringSync('');
    final target = File('${outside.path}/source_test.dart')..writeAsStringSync('');
    Link('${tests.path}/linked_test.dart').createSync(target.path);
    Link('${tests.path}/linked_directory').createSync(outside.path);
    Link('${tests.path}/dangling_test.dart').createSync('${outside.path}/missing.dart');
    expect(discoverFlutterTests(tests).toSet(), {
      '${tests.path}/real_test.dart',
      '${nested.path}/nested_test.dart',
      '${tests.path}/linked_test.dart',
    });
  });

  test('only a fresh terminal successful JSON run proves completion', () {
    expect(
      successfulTestRun('{"type":"testDone","result":"success"}\n{"type":"done","success":true}\n'),
      isTrue,
    );
    for (final report in [
      '',
      '{"type":"testDone","result":"success"}\n',
      '{"type":"done","success":false}\n',
      '{"type":"done","success":true}\n{"type":"print"}\n',
      '{"type":"done","success":true}\n{"type":"done","success":true}\n',
      '{"type":"error"}\n{"type":"done","success":true}\n',
      '{"type":"done","success":true}\nnot JSON\n',
      '[]\n',
    ]) {
      expect(successfulTestRun(report), isFalse, reason: report);
    }
  });

  test('zero exit cannot pass an incomplete JSON run or publish coverage', () async {
    var writes = 0;
    final result = await executeFlutterBatches(
      batches: [
        ['test/a_test.dart'],
      ],
      arguments: ['--coverage'],
      run: (_) async => 0,
      verify: (_) async => false,
      coveragePath: (_) => 'fresh/batch.info',
      read: (_) async => 'SF:a\nDA:1,1\nend_of_record\n',
      write: (_) async => writes++,
    );
    expect(result, 1);
    expect(writes, 0);
  });

  test('failed batches remain failures and do not skip later tests', () async {
    final calls = <List<String>>[];
    String? written;
    final result = await executeFlutterBatches(
      batches: [
        ['test/a_test.dart'],
        ['test/b_test.dart'],
      ],
      arguments: ['--coverage', '--exclude-tags', 'render || ffmpeg'],
      run: (args) async {
        calls.add(args);
        return calls.length == 1 ? 1 : 0;
      },
      verify: (_) async => true,
      coveragePath: (index) => 'fresh/batch-$index.info',
      read: (_) async => 'SF:lib/a.dart\nDA:1,1\nend_of_record\n',
      write: (report) async => written = report,
    );
    expect(result, 1);
    expect(calls, [
      [
        'test',
        'test/a_test.dart',
        '--coverage',
        '--exclude-tags',
        'render || ffmpeg',
        '--coverage-path',
        'fresh/batch-0.info',
      ],
      [
        'test',
        'test/b_test.dart',
        '--coverage',
        '--exclude-tags',
        'render || ffmpeg',
        '--coverage-path',
        'fresh/batch-1.info',
      ],
    ]);
    expect(written, isNull, reason: 'A nonzero process cannot publish successful coverage');
  });

  test('missing fresh coverage fails and never publishes partial reports', () async {
    var writes = 0;
    final result = await executeFlutterBatches(
      batches: [
        ['test/a_test.dart'],
        ['test/b_test.dart'],
      ],
      arguments: ['--coverage'],
      run: (_) async => 0,
      coveragePath: (index) => 'fresh/batch-$index.info',
      verify: (_) async => true,
      read: (path) async => path.endsWith('0.info') ? 'SF:a\nDA:1,1\nend_of_record\n' : null,
      write: (_) async => writes++,
    );
    expect(result, 1);
    expect(writes, 0);
  });

  test('completed empty coverage does not invent executable lines', () async {
    String? published;
    final result = await executeFlutterBatches(
      batches: [
        ['test/analysis_fixture_test.dart'],
      ],
      arguments: ['--coverage'],
      run: (_) async => 0,
      verify: (_) async => true,
      coveragePath: (_) => 'fresh/empty.info',
      read: (_) async => '',
      write: (report) async => published = report,
    );
    expect(result, 0);
    expect(published, isEmpty);
  });

  test('noncoverage run never reads, writes or injects coverage arguments', () async {
    final result = await executeFlutterBatches(
      batches: [
        ['test/a_test.dart'],
      ],
      arguments: ['--tags', 'golden'],
      run: (args) async {
        expect(args, ['test', 'test/a_test.dart', '--tags', 'golden']);
        return 0;
      },
      verify: (_) async => true,
      coveragePath: (_) => throw StateError('Unexpected coverage path'),
      read: (_) => throw StateError('Unexpected coverage read'),
      write: (_) => throw StateError('Unexpected coverage write'),
    );
    expect(result, 0);
  });

  test('empty execution plan cannot pass', () async {
    await expectLater(
      executeFlutterBatches(
        batches: [],
        arguments: [],
        run: (_) async => 0,
        verify: (_) async => true,
        coveragePath: (_) => '',
        read: (_) async => null,
        write: (_) async {},
      ),
      throwsArgumentError,
    );
  });

  test('bounded batches retain every discovered test exactly once', () {
    final files = ['test/z_test.dart', 'test/a_test.dart', 'test/b_test.dart'];
    final batches = flutterSuiteBatches(files, maxFiles: 2);
    expect(batches, [
      ['test/a_test.dart', 'test/b_test.dart'],
      ['test/z_test.dart'],
    ]);
    expect(batches.expand((batch) => batch).toSet(), files.toSet());
    expect(files.first, 'test/z_test.dart', reason: 'Do not mutate the input manifest');
  });

  test('invalid batch size, duplicate paths and empty paths fail loudly', () {
    expect(() => flutterSuiteBatches(['a'], maxFiles: 0), throwsArgumentError);
    expect(() => flutterSuiteBatches(['a', 'a']), throwsArgumentError);
    expect(() => flutterSuiteBatches(['']), throwsArgumentError);
    expect(flutterSuiteBatches([]), isEmpty);
  });

  test('coverage union adds hits while retaining unexecuted lines', () {
    final merged = mergeLineCoverage([
      'SF:lib/a.dart\nDA:1,2\nDA:2,0\nLF:2\nLH:1\nend_of_record\n',
      'SF:lib/a.dart\nDA:1,3\nDA:3,7\nend_of_record\n',
      'SF:lib/b.dart\nDA:4,0\nend_of_record\n',
    ]);
    expect(
      merged,
      'SF:lib/a.dart\nDA:1,5\nDA:2,0\nDA:3,7\nLF:3\nLH:2\nend_of_record\n'
      'SF:lib/b.dart\nDA:4,0\nLF:1\nLH:0\nend_of_record\n',
    );
  });

  test('coverage output is deterministic regardless of report order', () {
    const first = 'SF:lib/z.dart\nDA:9,1\nDA:3,0\nend_of_record\n';
    const second = 'TN:batch\nSF:lib/a.dart\nDA:2,1\nend_of_record\n';
    expect(mergeLineCoverage([first, second]), mergeLineCoverage([second, first]));
  });

  test('corrupt, incomplete and unsupported coverage cannot yield green data', () {
    for (final report in [
      'DA:1,2\n',
      'SF:\nend_of_record\n',
      'SF:a\nDA:1,2\n',
      'SF:a\nSF:b\nend_of_record\n',
      'SF:a\nDA:0,2\nend_of_record\n',
      'SF:a\nDA:1,-1\nend_of_record\n',
      'SF:a\nDA:x,2\nend_of_record\n',
      'SF:a\nDA:1,2,checksum\nend_of_record\n',
      'SF:a\nBRDA:1,0,0,1\nend_of_record\n',
    ]) {
      expect(() => mergeLineCoverage([report]), throwsFormatException, reason: report);
    }
    expect(() => mergeLineCoverage([]), throwsFormatException);
    expect(() => mergeLineCoverage(['']), throwsFormatException);
  });
}
