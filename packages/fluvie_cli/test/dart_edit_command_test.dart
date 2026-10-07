import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/dart_edit_command.dart';
import 'package:fluvie_cli/src/edit_command.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _NativeAuthorRunner implements ProcessRunner {
  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (args.contains('--dart-define=FLUVIE_OPERATION=author')) {
      final api = args.singleWhere(
        (arg) => arg.startsWith('--dart-define=FLUVIE_AI_DART_API_B64='),
      );
      expect(
        utf8.decode(base64Decode(api.split('=').skip(2).join('='))),
        contains('Dart API examples'),
      );
      final path = args
          .singleWhere((arg) => arg.startsWith('--dart-define=FLUVIE_RENDER_SPEC_OUT='))
          .substring('--dart-define=FLUVIE_RENDER_SPEC_OUT='.length);
      File(path).writeAsStringSync('{"edits":[{"before":"Miso","after":"Cat"}]}');
    }
    return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
  }
}

void main() {
  test(
    'native source outside the caller directory discovers its own project and notes',
    () async {
      final dir = Directory.systemTemp.createTempSync('fluvie_external_native_edit_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(
        '${dir.path}/pubspec.yaml',
      ).writeAsStringSync('name: cat_video\ndependencies:\n  fluvie: any\n');
      final configFile = File('../../.dart_tool/package_config.json');
      final config = jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
      for (final package in (config['packages']! as List<Object?>).cast<Map<String, Object?>>()) {
        package['rootUri'] = configFile.absolute.uri
            .resolve(package['rootUri']! as String)
            .toString();
      }
      File('${dir.path}/.dart_tool/package_config.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(config));
      File('${dir.path}/assets/notes.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync('Miso is my cat.');
      final source = File('${dir.path}/lib/cat.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("Video build() => cat('Miso');");
      final command = EditCommand(
        runner: _NativeAuthorRunner(),
        environment: const {'FLUVIE_AI_PROVIDER': 'ollama'},
        resolveFfmpeg: (runner, {binary, allowDownload = true, log = print}) async => 'unused',
        validateDart: (_, _) async {},
      );
      final err = StringBuffer();
      for (final input in [source.path, p.relative(source.path)]) {
        source.writeAsStringSync("Video build() => cat('Miso');");
        expect(
          await command.execute(
            EditCommand.buildParser().parse([
              input,
              'rename',
              '--no-render',
              '--context-file',
              'assets/notes.txt',
            ]),
            out: StringBuffer(),
            err: err,
          ),
          0,
          reason: err.toString(),
        );
        expect(source.readAsStringSync(), "Video build() => cat('Cat');");
      }
    },
  );

  test(
    'native edit publishes validated source and backup, without rendering when requested',
    () async {
      final dir = Directory.systemTemp.createTempSync('fluvie_native_edit_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final source = File('${dir.path}/lib/cat.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("// Handwritten widget.\nVideo build() => customVideo('Miso');\n");
      var validated = false;
      var rendered = false;
      final out = StringBuffer();
      final code = await executeDartEdit(
        args: EditCommand.buildParser().parse([
          source.path,
          'name is Cat',
          '--no-render',
          '--machine',
        ]),
        out: out,
        err: StringBuffer(),
        requestEdits: (_) async => jsonEncode({
          'edits': [
            {'before': "'Miso'", 'after': "'Cat'"},
          ],
        }),
        validate: (_) async => validated = true,
        render: (_) async {
          rendered = true;
          return 0;
        },
      );
      expect(code, 0);
      expect(validated, isTrue);
      expect(rendered, isFalse);
      expect(
        source.readAsStringSync(),
        "// Handwritten widget.\nVideo build() => customVideo('Cat');\n",
      );
      final event = jsonDecode(out.toString().trim()) as Map<String, Object?>;
      expect(event['event'], 'edited');
      expect(File(event['backupPath']! as String).readAsStringSync(), contains("'Miso'"));
    },
  );

  test('render failure preserves the independently validated edited Dart artifact', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_native_edit_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final source = File('${dir.path}/cat.dart')..writeAsStringSync("Video build() => cat('Miso');");
    await expectLater(
      executeDartEdit(
        args: EditCommand.buildParser().parse([source.path, 'rename']),
        out: StringBuffer(),
        err: StringBuffer(),
        requestEdits: (_) async => '{"edits":[{"before":"Miso","after":"Cat"}]}',
        validate: (_) async {},
        render: (_) async => throw const CliFailure('Encoder unavailable.'),
      ),
      throwsA(isA<CliFailure>()),
    );
    expect(source.readAsStringSync(), contains("'Cat'"));
  });

  test('edit command routes .dart sources through exact patches and compiled validation', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_native_edit_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File(
      '${dir.path}/pubspec.yaml',
    ).writeAsStringSync('name: cat_video\ndependencies:\n  fluvie: any\n');
    final source = File('${dir.path}/lib/cat.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("// Keep my imports.\nVideo build() => customCat('Miso');\n");
    final out = StringBuffer();
    final err = StringBuffer();
    final command = EditCommand(
      environment: const {'FLUVIE_AI_PROVIDER': 'ollama'},
      requestDartEdits: (_, original) async => '{"edits":[{"before":"Miso","after":"Cat"}]}',
      validateDart: (_, pending) async {
        expect(pending.parent.path, source.parent.path);
        expect(pending.readAsStringSync(), contains('Cat'));
      },
    );
    final code = await command.execute(
      EditCommand.buildParser().parse([
        'lib/cat.dart',
        'rename to Cat',
        '--project',
        dir.path,
        '--no-render',
      ]),
      out: out,
      err: err,
    );
    expect(code, 0, reason: err.toString());
    expect(source.readAsStringSync(), "// Keep my imports.\nVideo build() => customCat('Cat');\n");
  });
}
