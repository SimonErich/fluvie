import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const _oldCoverage = 'previous measured coverage\n';
const _freshCoverage = 'SF:lib/current.dart\nDA:1,2\nDA:2,0\nLF:2\nLH:1\nend_of_record\n';
final _dart = '${File(Platform.resolvedExecutable).parent.path}/dart';

void main() {
  test('CLI publishes only fresh coverage and retains the current run evidence', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(fixture.coverage.readAsStringSync(), _freshCoverage);
    expect(fixture.stale.readAsStringSync(), contains('lib/excluded.dart'));
    final calls = fixture.calls;
    expect(calls, hasLength(2));
    final testArgs = (calls.first['arguments']! as List<Object?>).cast<String>();
    expect(testArgs, containsAllInOrder(['test', '-j1', '--exclude-tags']));
    expect(testArgs, contains('ffmpeg || download || render || analysis || generative'));
    final raw = testArgs.singleWhere((arg) => arg.startsWith('--coverage=')).substring(11);
    final formatArgs = (calls.last['arguments']! as List<Object?>).cast<String>();
    expect(formatArgs, contains('--in=$raw'));
    expect(formatArgs, contains('--report-on=lib'));
    expect(raw, isNot(fixture.coverage.parent.path));
    expect(File('$raw/test/current.vm.json').existsSync(), isTrue);
    expect(fixture.reports, hasLength(1));
    expect(fixture.reports.single.readAsStringSync(), contains('"success":true'));
    final runtime = calls.first['temp']! as String;
    expect(runtime, startsWith('${fixture.temp.path}/'));
    expect(runtime, isNot(startsWith(fixture.package.path)));
    expect(Directory(runtime).existsSync(), isFalse);
  });

  test('failed Dart tests preserve previous coverage even with successful terminal JSON', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run(testMode: 'exit');
    expect(result.exitCode, 7, reason: '${result.stdout}\n${result.stderr}');
    expect(fixture.coverage.readAsStringSync(), _oldCoverage);
    expect(fixture.calls, hasLength(1), reason: 'Never format a failed test run');
    expect(fixture.reports.single.readAsStringSync(), contains('"success":true'));
  });

  test('zero exit with incomplete JSON cannot publish or format coverage', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run(testMode: 'incomplete');
    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(fixture.coverage.readAsStringSync(), _oldCoverage);
    expect(fixture.calls, hasLength(1));
    expect(fixture.reports.single.readAsStringSync(), contains('"type":"testDone"'));
  });

  test('failed formatter preserves previous coverage even if it writes valid LCOV', () async {
    final fixture = await _Fixture.create();
    final result = await fixture.run(formatMode: 'exit');
    expect(result.exitCode, 9, reason: '${result.stdout}\n${result.stderr}');
    expect(fixture.coverage.readAsStringSync(), _oldCoverage);
    expect(fixture.calls, hasLength(2));
    expect(fixture.reports, hasLength(1));
    final arguments = (fixture.calls.last['arguments']! as List<Object?>).cast<String>();
    final output = arguments.singleWhere((arg) => arg.startsWith('--out=')).substring(6);
    expect(File(output).readAsStringSync(), contains('SF:lib/current.dart'));
  });

  for (final mode in ['missing', 'error', 'corrupt']) {
    test('zero exit with $mode JSON preserves previous coverage', () async {
      final fixture = await _Fixture.create();
      final result = await fixture.run(testMode: mode);
      expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
      expect(fixture.coverage.readAsStringSync(), _oldCoverage);
      expect(fixture.calls, hasLength(1));
      expect(fixture.reports, hasLength(mode == 'missing' ? 0 : 1));
    });
  }

  for (final mode in ['missing', 'corrupt', 'empty']) {
    test('zero exit formatter with $mode LCOV preserves previous coverage', () async {
      final fixture = await _Fixture.create();
      final result = await fixture.run(formatMode: mode);
      expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
      expect(fixture.coverage.readAsStringSync(), _oldCoverage);
      expect(fixture.calls, hasLength(2));
      expect(fixture.reports, hasLength(1));
    });
  }

  test('consecutive CLI runs retain disjoint reports and never reuse prior VM inputs', () async {
    final fixture = await _Fixture.create();
    final first = await fixture.run();
    expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
    final firstArgs = (fixture.calls.first['arguments']! as List<Object?>).cast<String>();
    final oldRaw = firstArgs.singleWhere((arg) => arg.startsWith('--coverage=')).substring(11);
    File(
      '$oldRaw/test/current.vm.json',
    ).writeAsStringSync('{"source":"lib/previous-run.dart","hits":{"5":99}}');
    final second = await fixture.run();
    expect(second.exitCode, 0, reason: '${second.stdout}\n${second.stderr}');
    final nextArgs = (fixture.calls[2]['arguments']! as List<Object?>).cast<String>();
    final nextRaw = nextArgs.singleWhere((arg) => arg.startsWith('--coverage=')).substring(11);
    expect(nextRaw, isNot(oldRaw));
    expect(fixture.coverage.readAsStringSync(), _freshCoverage);
    expect(fixture.reports, hasLength(2));
    expect(File('$oldRaw/test/current.vm.json').readAsStringSync(), contains('previous-run'));
  });

  test('real Dart suite and formatter publish measured lines and exclude render tests', () async {
    final fixture = await _Fixture.create();
    File('${fixture.package.path}/pubspec.yaml').writeAsStringSync(
      'name: studio_dart_fixture\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n'
      'dev_dependencies:\n  coverage: any\n  test: any\n',
    );
    final configuration = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(configuration.readAsStringSync()) as Map<String, Object?>;
    final packages = (config['packages']! as List<Object?>).cast<Map<String, Object?>>();
    for (final package in packages) {
      package['rootUri'] = configuration.uri.resolve(package['rootUri']! as String).toString();
    }
    packages.add({
      'name': 'studio_dart_fixture',
      'rootUri': fixture.package.uri.toString(),
      'packageUri': 'lib/',
      'languageVersion': '3.0',
    });
    final output = File('${fixture.package.path}/.dart_tool/package_config.json');
    output.parent.createSync();
    output.writeAsStringSync(jsonEncode(config));
    final library = File('${fixture.package.path}/lib/answer.dart');
    library.parent.createSync();
    library.writeAsStringSync('int answer() => 42;\n');
    final tests = File('${fixture.package.path}/test/answer_test.dart');
    tests.parent.createSync();
    tests.writeAsStringSync(
      "import 'package:test/test.dart';\nimport '../lib/answer.dart';\n"
      "void main() {\n  test('measured answer', () => expect(answer(), 42));\n"
      "  test('excluded render', () => fail('must stay excluded'), tags: 'render');\n}\n",
    );
    final result = await fixture.run(boundary: false);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
      fixture.coverage.readAsStringSync(),
      'SF:${library.path}\nDA:1,1\nLF:1\nLH:1\nend_of_record\n',
    );
    final events = fixture.reports.single
        .readAsLinesSync()
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .toList();
    expect(events.last, containsPair('success', true));
    expect(events.where((event) => event['type'] == 'error'), isEmpty);
    expect(
      events
          .where((event) => event['type'] == 'testStart')
          .map((event) => (event['test']! as Map<String, Object?>)['name']),
      isNot(contains('excluded render')),
    );
    expect(fixture.stale.readAsStringSync(), contains('lib/excluded.dart'));
    expect(fixture.temp.listSync(), isEmpty, reason: 'Owned external runtime was removed');
  });
}

final class _Fixture {
  _Fixture(this.root, this.package, this.temp, this.runner);

  final Directory root;
  final Directory package;
  final Directory temp;
  final String runner;

  File get coverage => File('${package.path}/coverage/lcov.info');
  File get stale => File('${package.path}/coverage/test/stale.vm.json');
  List<Map<String, Object?>> get calls => File(
    '${root.path}/calls.jsonl',
  ).readAsLinesSync().map((line) => jsonDecode(line) as Map<String, Object?>).toList();
  List<File> get reports => Directory('${package.path}/build')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.jsonl'))
      .toList();

  static Future<_Fixture> create() async {
    final root = Directory.systemTemp.createTempSync('.studio-dart-suite-test-').absolute;
    addTearDown(() => root.deleteSync(recursive: true));
    final package = Directory('${root.path}/package')..createSync();
    final temp = Directory('${root.path}/system-temp')..createSync();
    final fixture = _Fixture(root, package, temp, File('tool/run_dart_suite.dart').absolute.path);
    fixture.coverage.parent.createSync(recursive: true);
    fixture.coverage.writeAsStringSync(_oldCoverage);
    fixture.stale.parent.createSync();
    fixture.stale.writeAsStringSync('{"source":"lib/excluded.dart","hits":{"9":17}}');
    final bin = Directory('${root.path}/bin')..createSync();
    final boundary = File('${root.path}/boundary.dart')..writeAsStringSync(_boundary);
    final executable = File('${bin.path}/dart')
      ..writeAsStringSync(
        '#!/bin/sh\nexec ${_quote(_dart)} '
        '${_quote(boundary.path)} "\$@"\n',
      );
    final permissions = await Process.run('chmod', ['+x', executable.path]);
    expect(permissions.exitCode, 0, reason: '${permissions.stderr}');
    return fixture;
  }

  Future<ProcessResult> run({
    String testMode = 'success',
    String formatMode = 'success',
    bool boundary = true,
  }) => Process.run(
    _dart,
    ['--suppress-analytics', 'run', runner],
    workingDirectory: package.path,
    environment: {
      'PATH': '${boundary ? '${root.path}/bin:' : ''}${Platform.environment['PATH'] ?? ''}',
      'TMPDIR': temp.path,
      'STUDIO_BOUNDARY_TRACE': '${root.path}/calls.jsonl',
      'STUDIO_TEST_MODE': testMode,
      'STUDIO_FORMAT_MODE': formatMode,
    },
  );
}

String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";

const _boundary = r'''
import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final test = arguments.contains('test');
  File(Platform.environment['STUDIO_BOUNDARY_TRACE']!).writeAsStringSync(
    '${jsonEncode({'arguments': arguments, 'temp': Platform.environment['TMPDIR']})}\n',
    mode: FileMode.append,
  );
  if (test) {
    final raw = arguments.singleWhere((arg) => arg.startsWith('--coverage=')).substring(11);
    final file = File('$raw/test/current.vm.json');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('{"source":"lib/current.dart","hits":{"1":2,"2":0}}');
    final report = File(arguments[arguments.indexOf('--file-reporter') + 1].substring(5));
    report.parent.createSync(recursive: true);
    final mode = Platform.environment['STUDIO_TEST_MODE'];
    if (mode != 'missing') {
      report.writeAsStringSync(switch (mode) {
        'incomplete' => '{"type":"testDone","result":"success"}\n',
        'error' => '{"type":"error"}\n{"type":"done","success":true}\n',
        'corrupt' => 'not JSON\n',
        _ => '{"type":"testDone","result":"success"}\n{"type":"done","success":true}\n',
      });
    }
    exitCode = mode == 'exit' ? 7 : 0;
    return;
  }
  final mode = Platform.environment['STUDIO_FORMAT_MODE'];
  if (mode == 'missing') return;
  final output = File(arguments.singleWhere((arg) => arg.startsWith('--out=')).substring(6));
  if (mode == 'empty') { output.writeAsStringSync(''); return; }
  if (mode == 'corrupt') { output.writeAsStringSync('SF:lib/current.dart\nDA:1,-4\n'); return; }
  final input = Directory(arguments.singleWhere((arg) => arg.startsWith('--in=')).substring(5));
  final result = StringBuffer();
  for (final file in input.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.vm.json')) continue;
    final record = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    result.writeln('SF:${record['source']}');
    final hits = record['hits']! as Map<String, Object?>;
    for (final entry in hits.entries) { result.writeln('DA:${entry.key},${entry.value}'); }
    result.writeln('end_of_record');
  }
  output.writeAsStringSync(result.toString());
  exitCode = mode == 'exit' ? 9 : 0;
}
''';
