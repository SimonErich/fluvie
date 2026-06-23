import 'dart:convert';
import 'dart:io';

import 'package:fluvie_server/src/api/render/render_code_printer.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('fluvie_printer_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  String write(String name, Object? json) {
    final path = '${dir.path}/$name';
    File(path).writeAsStringSync(jsonEncode(json));
    return path;
  }

  Map<String, Object?> validSpec() => {
    'fluvieSpec': 1,
    'size': 'square',
    'fps': 30,
    'scenes': [
      {
        'duration': '2s',
        'children': [
          {'type': 'Text', 'text': 'hi'},
        ],
      },
    ],
  };

  group('readSpecFileOrNull', () {
    test('returns the decoded map for a valid spec file', () {
      expect(readSpecFileOrNull(write('spec.json', validSpec())), validSpec());
    });

    test('returns null for a missing file', () {
      expect(readSpecFileOrNull('${dir.path}/absent.json'), isNull);
    });

    test('returns null when the JSON is not an object', () {
      expect(readSpecFileOrNull(write('arr.json', const [1, 2, 3])), isNull);
    });

    test('returns null for malformed JSON', () {
      final path = '${dir.path}/bad.json';
      File(path).writeAsStringSync('{not json');
      expect(readSpecFileOrNull(path), isNull);
    });
  });

  group('SpecCodeWatcher', () {
    test('exposes the printed code and the decoded spec once printable', () async {
      final path = write('spec.json', validSpec());
      final authored = <(String, Map<String, Object?>)>[];
      final watcher = SpecCodeWatcher(
        specPath: path,
        interval: const Duration(milliseconds: 5),
        onAuthored: (code, spec) => authored.add((code, spec)),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      watcher.flush();

      expect(watcher.code, contains('Video build()'));
      expect(watcher.spec, validSpec());
      expect(authored.single.$1, watcher.code);
      expect(authored.single.$2, validSpec());
    });

    test('flush catches a spec the poll never saw, firing once', () async {
      final path = '${dir.path}/late.json';
      final authored = <(String, Map<String, Object?>)>[];
      final watcher = SpecCodeWatcher(
        specPath: path,
        interval: const Duration(hours: 1),
        onAuthored: (code, spec) => authored.add((code, spec)),
      );

      File(path).writeAsStringSync(jsonEncode(validSpec()));
      watcher.flush();

      expect(watcher.code, isNotNull);
      expect(watcher.spec, validSpec());
      expect(authored, hasLength(1));
    });

    test('a malformed spec leaves code and spec null and never fires', () async {
      final path = write('bogus.json', {
        'scenes': [
          {
            'duration': '1s',
            'children': [
              {'type': 'Bogus'},
            ],
          },
        ],
      });
      var fired = false;
      final watcher = SpecCodeWatcher(
        specPath: path,
        interval: const Duration(milliseconds: 5),
        onAuthored: (_, _) => fired = true,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      watcher.flush();

      expect(watcher.code, isNull);
      expect(watcher.spec, isNull);
      expect(fired, isFalse);
    });
  });
}
