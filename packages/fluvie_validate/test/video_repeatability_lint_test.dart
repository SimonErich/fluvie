import 'dart:io';

import 'package:fluvie_validate/fluvie_validate.dart';
import 'package:test/test.dart';

void main() {
  final analyzer = FluvieCodeAnalyzer(projectRoot: Directory.current);
  tearDownAll(analyzer.dispose);

  test('video validation identifies wall clocks and unseeded randomness with remedies', () async {
    final diagnostics = await analyzer.analyze('''
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' as f;

f.Video build() => f.Video(scenes: [
  f.Scene(duration: const f.Time.seconds(1), children: [
    f.FrameBuilder((_) => Text([
      DateTime.now(),
      DateTime.timestamp(),
      math.Random().nextDouble(),
      math.Random(null).nextDouble(),
      math.Random.secure().nextDouble(),
    ].join(' '))),
  ]),
]);
''');
    expect(diagnostics.where((item) => item.severity == FluvieDiagnosticSeverity.error), isEmpty);
    final warnings = diagnostics.where((item) => item.code == 'nondeterministic_video').toList();
    expect(warnings, hasLength(5));
    expect(warnings.map((item) => item.line), [8, 9, 10, 11, 12]);
    expect(warnings.every((item) => item.severity == FluvieDiagnosticSeverity.warning), isTrue);
    expect(warnings.first.message, contains('authored frame'));
    expect(warnings.last.message, contains('seed'));
    expect(warnings.every((item) => item.length != null && item.length! > 0), isTrue);
  });

  test('fixed time and seeded randomness are valid video inputs', () async {
    final diagnostics = await analyzer.analyze('''
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';

Video build() => Video(scenes: [
  Scene(duration: const Time.seconds(1), children: [
    FrameBuilder((_) => Text([
      DateTime.utc(2026), Random(42).nextDouble(),
    ].join(' '))),
  ]),
]);
''');
    expect(diagnostics.where((item) => item.severity == FluvieDiagnosticSeverity.error), isEmpty);
    expect(diagnostics.where((item) => item.code == 'nondeterministic_video'), isEmpty);
  });

  test('ordinary application clocks and unrelated names do not produce video warnings', () async {
    final diagnostics = await analyzer.analyze(r'''
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' as f;

class Video { Video(Object value); }
class Random { Random(); }
String applicationStatus() => '${DateTime.now()} ${math.Random().nextDouble()}';
Video unrelated() => Video(DateTime.now());
f.Video build() => f.Video(scenes: [
  f.Scene(duration: const f.Time.seconds(1), children: [
    Text(Random().toString()),
    GestureDetector(onTap: () { DateTime.now(); }, child: const Text('fixed')),
  ]),
]);
''');
    expect(diagnostics.where((item) => item.severity == FluvieDiagnosticSeverity.error), isEmpty);
    expect(diagnostics.where((item) => item.code == 'nondeterministic_video'), isEmpty);
  });

  test('standard ignore directives apply to Fluvie warnings and preserve compile errors', () async {
    const body = '''
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
Video build() => Video(scenes: [
  Scene(duration: const Time.seconds(1), children: [
    Text(DateTime.now().toString()),
    Text(missingValue),
  ]),
]);
''';
    final ignoredFile = await analyzer.analyze('// ignore_for_file: nondeterministic_video\n$body');
    expect(ignoredFile.where((item) => item.code == 'nondeterministic_video'), isEmpty);
    expect(
      ignoredFile.where((item) => item.severity == FluvieDiagnosticSeverity.error),
      hasLength(1),
    );
    final ignoredLine = await analyzer.analyze(
      body.replaceFirst(
        '    Text(DateTime.now()',
        '    // ignore: nondeterministic_video\n    Text(DateTime.now()',
      ),
    );
    expect(ignoredLine.where((item) => item.code == 'nondeterministic_video'), isEmpty);
  });

  test('ignore-looking strings never suppress a real warning', () async {
    final diagnostics = await analyzer.analyze('''
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
Video build() => Video(scenes: [
  Scene(duration: const Time.seconds(1), children: [
    const Text('// ignore_for_file: nondeterministic_video'),
    Text(DateTime.now().toString()),
  ]),
]);
''');
    expect(diagnostics.where((item) => item.code == 'nondeterministic_video'), hasLength(1));
  });

  test('line directives affect only their exact line, including trailing comments', () async {
    final diagnostics = await analyzer.analyze(
      '''
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
Video build() => Video(scenes: [
  Scene(duration: const Time.seconds(1), children: [
    Text(DateTime.now().toString()), // ignore: unused_import, NONDETERMINISTIC_VIDEO
    Text(DateTime.now().toString()),
    // ignore: nondeterministic_video
    const Text('fixed'),
    Text(DateTime.now().toString()),
  ]),
]);
// ignore: nondeterministic_video
'''
          .replaceAll('\n', '\r\n'),
    );
    final warnings = diagnostics.where((item) => item.code == 'nondeterministic_video').toList();
    expect(warnings.map((item) => item.line), [6, 9]);
  });

  test('type=lint directives suppress custom rules without hiding compiler errors', () async {
    final diagnostics = await analyzer.analyze('''
// ignore_for_file: type=lint
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
Video build() => Video(scenes: [
  Scene(duration: const Time.seconds(1), children: [
    Text(DateTime.now().toString()),
    Text(missingValue),
  ]),
]);
''');
    expect(diagnostics.where((item) => item.code == 'nondeterministic_video'), isEmpty);
    expect(
      diagnostics.where((item) => item.severity == FluvieDiagnosticSeverity.error),
      hasLength(1),
    );
  });

  test('invalid random arguments remain compiler diagnostics rather than a lint crash', () async {
    final diagnostics = await analyzer.analyze('''
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
Video build() => Video(scenes: [
  Scene(duration: const Time.seconds(1), children: [
    Text(Random(1, 2).toString()),
  ]),
]);
''');
    expect(
      diagnostics.where((item) => item.severity == FluvieDiagnosticSeverity.error),
      hasLength(1),
    );
    expect(diagnostics.where((item) => item.code == 'nondeterministic_video'), isEmpty);
  });
}
