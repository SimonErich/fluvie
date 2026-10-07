import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _CaptureRunner implements ProcessRunner {
  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    if (args.contains('-version')) {
      return ProcessRunResult(
        exitCode: 0,
        stdout: '${executable.contains('ffprobe') ? 'ffprobe' : 'ffmpeg'} version 8.0\n',
        stderr: '',
      );
    }
    if (executable == 'flutter' && args.contains('test')) {
      String define(String name) => args
          .singleWhere((arg) => arg.startsWith('--dart-define=$name='))
          .split('=')
          .skip(2)
          .join('=');
      final directory = define('FLUVIE_RENDER_OUT_DIR');
      final operation = define('FLUVIE_OPERATION');
      final file = File(p.join(directory, operation == 'frame' ? 'frame.png' : 'inspection.json'))
        ..writeAsStringSync(
          operation == 'frame'
              ? 'PNG fixture'
              : jsonEncode({
                  'schemaVersion': 1,
                  'totalFrames': 3,
                  'width': 64,
                  'height': 48,
                  'fps': 3,
                  'scenes': [<String, Object?>{}],
                  'hasAudio': false,
                }),
        );
      File(p.join(directory, 'render-result.json')).writeAsStringSync(
        jsonEncode({'schemaVersion': 1, 'kind': operation, 'filePath': file.path}),
      );
    }
    return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
  }
}

void main() {
  for (final operation in ['inspect', 'frame']) {
    test('$operation machine output ends with a parseable typed result', () async {
      final directory = Directory.systemTemp.createTempSync('fluvie_machine_tool_');
      addTearDown(() => directory.deleteSync(recursive: true));
      File(
        p.join(directory.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: fixture\ndependencies:\n  fluvie: any\n');
      final configFile = File('../../.dart_tool/package_config.json');
      final config = jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
      for (final package in (config['packages']! as List<Object?>).cast<Map<String, Object?>>()) {
        package['rootUri'] = configFile.absolute.uri
            .resolve(package['rootUri']! as String)
            .toString();
      }
      File(p.join(directory.path, '.dart_tool/package_config.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(config));
      final source = File(p.join(directory.path, 'lib/cat.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('Video build() => cat();');
      final out = StringBuffer();
      final err = StringBuffer();
      final runner = _CaptureRunner();
      final code = await run(
        [operation, source.path, '--toolchain', 'system', '--machine'],
        inspect: InspectCommand(runner: runner),
        frame: FrameCommand(runner: runner),
        out: out,
        err: err,
      );
      expect(code, 0, reason: err.toString());
      final events = const LineSplitter()
          .convert(out.toString())
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .toList();
      expect(events.last['event'], operation == 'inspect' ? 'inspection' : 'frame');
      if (operation == 'inspect') {
        expect(events.last['totalFrames'], 3);
      } else {
        expect(events.last['frame'], 0);
        expect(File(events.last['filePath']! as String).existsSync(), isTrue);
      }
    });
  }
}
