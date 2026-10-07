import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/review_command.dart';
import 'package:test/test.dart';

void main() {
  test('render failure retains prepared sample evidence and the failing stage', () async {
    final project = Directory.systemTemp.createTempSync('fluvie_cli_review_failure_');
    addTearDown(() => project.deleteSync(recursive: true));
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: cat\n');
    final source = File('${project.path}/cat.dart')..writeAsStringSync('Video build() => cat();');
    final command = ReviewCommand(
      validate: (_) async => {'ok': true},
      capture: (_, _, _) async => {
        'samples': [
          {'frame': 1},
        ],
        'totalFrames': 3,
      },
      render: (_, _, _) async => throw StateError('cannot encode'),
    );
    final out = StringBuffer();
    expect(
      await command.execute(
        ReviewCommand.buildParser().parse([source.path, '--render', '--json']),
        out: out,
        err: StringBuffer(),
      ),
      1,
    );
    final report = jsonDecode(out.toString()) as Map<String, Object?>;
    expect(report['stage'], 'render');
    expect(report['validation'], containsPair('ok', true));
    expect(report['samples'], [
      {'frame': 1},
    ]);
    expect(report['error'], containsPair('code', 'review_failed'));
  });

  test(
    'review combines validation, mounted sample evidence, and deterministic-seek findings',
    () async {
      final project = Directory.systemTemp.createTempSync('fluvie_cli_review_');
      addTearDown(() => project.deleteSync(recursive: true));
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: cat\n');
      final source = File('${project.path}/lib/cat.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('Video build() => cat();');
      final out = StringBuffer();
      final err = StringBuffer();
      final command = ReviewCommand(
        validate: (_) async => {'ok': true, 'diagnostics': <Object?>[]},
        capture: (target, args, output) async {
          expect(target.path, source.path);
          expect(args.multiOption('samples'), ['0', '2']);
          return {
            'totalFrames': 3,
            'samples': [
              {'frame': 0},
              {'frame': 2},
            ],
            'determinism': {
              'checked': true,
              'ok': false,
              'mismatches': [
                {'frame': 0},
              ],
            },
          };
        },
      );
      final code = await command.execute(
        ReviewCommand.buildParser().parse([
          source.path,
          '--project',
          project.path,
          '--samples',
          '0,2',
          '--determinism',
          '--machine',
        ]),
        out: out,
        err: err,
      );
      expect(code, 1);
      final report = jsonDecode(out.toString()) as Map<String, Object?>;
      expect(report['ok'], isFalse);
      expect(report['event'], 'review');
      expect(report['samples'], hasLength(2));
      expect(report['validation'], containsPair('ok', true));
      expect(File(report['reportPath']! as String).existsSync(), isTrue);
    },
  );

  test(
    'static failure stops preparation; invalid sample arguments stop before validation',
    () async {
      final project = Directory.systemTemp.createTempSync('fluvie_cli_review_');
      addTearDown(() => project.deleteSync(recursive: true));
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: cat\n');
      final source = File('${project.path}/cat.dart')..writeAsStringSync('not Dart');
      var captured = false;
      var validated = 0;
      final command = ReviewCommand(
        validate: (_) async {
          validated++;
          return {
            'ok': false,
            'diagnostics': [
              {'line': 1, 'code': 'syntax_error'},
            ],
          };
        },
        capture: (_, _, _) async {
          captured = true;
          return {};
        },
      );
      final out = StringBuffer();
      expect(
        await command.execute(
          ReviewCommand.buildParser().parse([source.path, '--json']),
          out: out,
          err: StringBuffer(),
        ),
        1,
      );
      expect(captured, isFalse);
      expect(validated, 1);
      expect(jsonDecode(out.toString()), containsPair('stage', 'validate'));
      expect(
        await command.execute(
          ReviewCommand.buildParser().parse([source.path, '--samples', '-1']),
          out: StringBuffer(),
          err: StringBuffer(),
        ),
        64,
      );
      expect(validated, 1);
      expect(
        await command.execute(
          ReviewCommand.buildParser().parse([source.path, '--strict-decode']),
          out: StringBuffer(),
          err: StringBuffer(),
        ),
        64,
      );
    },
  );
}
