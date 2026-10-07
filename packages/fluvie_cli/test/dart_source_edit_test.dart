import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/dart_source_edit.dart';
import 'package:test/test.dart';

void main() {
  const source = "// Keep this comment.\r\nVideo build() => Video(name: 'Miso');\r\n";
  String patch(List<Map<String, String>> edits) => jsonEncode({'edits': edits});

  test('changes only selected exact bytes and accepts fenced JSON', () {
    final reply = patch([
      {'before': "'Miso'", 'after': "'Miso the cat'"},
    ]);
    expect(
      applyDartEdits(source, '```json\n$reply\n```'),
      source.replaceFirst("'Miso'", "'Miso the cat'"),
    );
  });

  test('rejects ambiguous, overlapping, empty, malformed and oversized edits', () {
    final invalid = [
      patch([
        {'before': 'i', 'after': 'x'},
      ]),
      patch([
        {'before': "name: 'Miso'", 'after': "name: 'Cat'"},
        {'before': "'Miso'", 'after': "'Other'"},
      ]),
      patch([
        {'before': '', 'after': 'x'},
      ]),
      patch([
        {'before': 'unknown', 'after': 'x'},
      ]),
      patch([]),
      '{"edits":[{"before":"Miso","after":null}]}',
      '{"edits":[],"other":1}',
      'not JSON',
      'x' * (256 * 1024 + 1),
    ];
    for (final reply in invalid) {
      expect(() => applyDartEdits(source, reply), throwsA(isA<CliFailure>()));
    }
  });

  group('publication', () {
    late Directory root;
    late File file;
    setUp(() {
      root = Directory.systemTemp.createTempSync('fluvie_dart_edit_');
      file = File('${root.path}/video.dart')..writeAsStringSync(source);
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('publication preserves UTF-8 BOM, Unicode text and CRLF bytes', () async {
      final original = [
        239,
        187,
        191,
        ...utf8.encode("// Miso 🐈\r\nVideo build() => cat('Miso');\r\n"),
      ];
      file.writeAsBytesSync(original);
      final result = await editDartSource(
        file: file,
        requestEdits: (_) async => patch([
          {'before': "'Miso'", 'after': "'Cat'"},
        ]),
        validate: (_) async {},
      );
      expect(file.readAsBytesSync(), [
        239,
        187,
        191,
        ...utf8.encode("// Miso 🐈\r\nVideo build() => cat('Cat');\r\n"),
      ]);
      expect(File(result.backupPath).readAsBytesSync(), original);
    });

    test('validates a sibling with relative imports intact, then backs up and replaces', () async {
      final result = await editDartSource(
        file: file,
        requestEdits: (original) async {
          expect(original, source);
          return patch([
            {'before': "'Miso'", 'after': "'Cat'"},
          ]);
        },
        validate: (pending) async {
          expect(pending.parent.path, file.parent.path);
          expect(file.readAsStringSync(), source);
          expect(pending.readAsStringSync(), contains("'Cat'"));
        },
      );
      expect(file.readAsStringSync(), source.replaceFirst("'Miso'", "'Cat'"));
      expect(File(result.backupPath).readAsStringSync(), source);
      expect(result.sourceHash, sha256.convert(file.readAsBytesSync()).toString());
      expect(root.listSync().whereType<File>().length, 2);
    });

    test('compiler feedback repairs against original bytes before publication', () async {
      var checks = 0;
      final result = await editDartSource(
        file: file,
        requestEdits: (_) async => patch([
          {'before': "'Miso'", 'after': "'Invalid'"},
        ]),
        validate: (candidate) async {
          checks++;
          if (checks == 1) throw const CliFailure('Unknown API', code: 'dart_validation_failed');
          expect(candidate.readAsStringSync(), contains("'Cat'"));
        },
        repairEdits: (original, feedback) async {
          expect(original, source);
          expect(feedback, 'Unknown API');
          expect(file.readAsStringSync(), source);
          return patch([
            {'before': "'Miso'", 'after': "'Cat'"},
          ]);
        },
      );
      expect(checks, 2);
      expect(File(result.backupPath).readAsStringSync(), source);
    });

    test('compiler repairs stop at their budget and never publish a failed candidate', () async {
      var repairs = 0;
      await expectLater(
        editDartSource(
          file: file,
          requestEdits: (_) async => patch([
            {'before': "'Miso'", 'after': "'Invalid'"},
          ]),
          validate: (_) async =>
              throw const CliFailure('Unknown API', code: 'dart_validation_failed'),
          repairEdits: (_, _) async {
            repairs++;
            return patch([
              {'before': "'Miso'", 'after': "'Invalid'"},
            ]);
          },
        ),
        throwsA(isA<CliFailure>()),
      );
      expect(repairs, 2);
      expect(file.readAsStringSync(), source);
      expect(File('${file.path}.fluvie.bak').existsSync(), isFalse);
    });

    test('validation failure leaves the original and existing backup untouched', () async {
      final backup = File('${file.path}.fluvie.bak')..writeAsStringSync('old backup');
      await expectLater(
        editDartSource(
          file: file,
          requestEdits: (_) async => patch([
            {'before': "'Miso'", 'after': "'Cat'"},
          ]),
          validate: (_) async => throw const CliFailure('Invalid composition.'),
        ),
        throwsA(isA<CliFailure>()),
      );
      expect(file.readAsStringSync(), source);
      expect(backup.readAsStringSync(), 'old backup');
      expect(root.listSync().whereType<File>().length, 2);
    });

    test('concurrent source edits cannot be overwritten after staged validation', () async {
      await expectLater(
        editDartSource(
          file: file,
          requestEdits: (_) async => patch([
            {'before': "'Miso'", 'after': "'Cat'"},
          ]),
          validate: (_) async => file.writeAsStringSync('User changed the source.'),
        ),
        throwsA(isA<CliFailure>()),
      );
      expect(file.readAsStringSync(), 'User changed the source.');
      expect(File('${file.path}.fluvie.bak').existsSync(), isFalse);
      expect(root.listSync().whereType<File>().length, 1);
    });
  });
}
