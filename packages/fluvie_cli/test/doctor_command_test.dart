import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/doctor_command.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;
  setUp(() {
    project = Directory.systemTemp.createTempSync('fluvie_doctor_');
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: cat_story\n');
    Directory(p.join(project.path, '.dart_tool')).createSync();
    File(p.join(project.path, '.dart_tool', 'package_config.json')).writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {'name': 'fluvie'},
        ],
      }),
    );
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('missing managed tools are actionable automatic setup, without writes or probes', () async {
    final out = StringBuffer();
    final runner = _DoctorRunner();
    final before = project.listSync(recursive: true).map((f) => f.path).toList()..sort();
    final exit = await DoctorCommand(runner: runner, environment: {'XDG_CACHE_HOME': project.path})
        .execute(
          DoctorCommand.buildParser().parse(['--json', '--project', project.path]),
          out: out,
          err: StringBuffer(),
        );
    final report = jsonDecode(out.toString()) as Map;
    expect(exit, 0);
    expect(report['ok'], true);
    final checks = report['checks'] as List;
    final media = checks.cast<Map<String, Object?>>().singleWhere((c) => c['id'] == 'media_tools');
    expect(media['status'], 'info');
    expect(media['details'], containsPair('automaticInstall', true));
    expect(media['fix'], contains('fluvie ffmpeg install'));
    expect(runner.executables, ['flutter']);
    final after = project.listSync(recursive: true).map((f) => f.path).toList()..sort();
    expect(after, before);
  });

  test('SDK below supported minimum is a blocking diagnostic', () async {
    final out = StringBuffer();
    expect(
      await DoctorCommand(
        runner: _DoctorRunner(flutter: '3.41.0', dart: '3.11.0'),
        environment: {'XDG_CACHE_HOME': project.path},
      ).execute(
        DoctorCommand.buildParser().parse(['--json', '--project', project.path]),
        out: out,
        err: StringBuffer(),
      ),
      1,
    );
    expect(out.toString(), contains('Flutter >=3.44 and Dart >=3.12'));
  });

  test('unresolved Fluvie and invalid explicit tools have concrete fixes', () async {
    File(p.join(project.path, '.dart_tool', 'package_config.json')).deleteSync();
    final out = StringBuffer();
    expect(
      await DoctorCommand(runner: _DoctorRunner(), environment: const {}).execute(
        DoctorCommand.buildParser().parse([
          '--json',
          '--project',
          project.path,
          '--ffmpeg',
          '/missing/ffmpeg',
        ]),
        out: out,
        err: StringBuffer(),
      ),
      1,
    );
    expect(out.toString(), contains('flutter pub add fluvie'));
    expect(out.toString(), contains('Fix the named executables'));
    expect(out.toString(), contains('"automaticInstall": false'));
  });
  test('installed pair reports codec capabilities without blocking custom renderers', () async {
    final out = StringBuffer();
    final runner = _DoctorRunner(tools: true);
    expect(
      await DoctorCommand(runner: runner, environment: const {}).execute(
        DoctorCommand.buildParser().parse([
          '--json',
          '--project',
          project.path,
          '--toolchain',
          'system',
        ]),
        out: out,
        err: StringBuffer(),
      ),
      0,
    );
    final checks = (jsonDecode(out.toString()) as Map)['checks'] as List;
    final encoders = checks.cast<Map<String, Object?>>().singleWhere(
      (c) => c['id'] == 'media_encoders',
    );
    expect(encoders['status'], 'info');
    expect(encoders['details'], containsPair('availableCommon', ['libx264', 'aac', 'pcm_s16le']));
    expect(encoders['details'], containsPair('missingCommon', ['libvpx-vp9', 'prores_ks']));
    expect(runner.executables, containsAll(['flutter', 'ffmpeg', 'ffprobe']));
  });
}

final class _DoctorRunner implements ProcessRunner {
  _DoctorRunner({this.flutter = '3.47.2', this.dart = '3.13.0', this.tools = false});
  final bool tools;
  final String flutter;
  final String dart;
  final List<String> executables = [];
  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    executables.add(executable);
    if (executable != 'flutter') {
      if (!tools) throw ProcessException(executable, args, 'Missing');
      final output = args.contains('-encoders')
          ? ' V....D libx264 H.264\n A..... aac AAC\n A..... pcm_s16le PCM\n'
          : args.contains('-decoders')
          ? ' V..... libvpx-vp9 VP9\n'
          : '$executable version 8.1.2';
      return ProcessRunResult(exitCode: 0, stdout: output, stderr: '');
    }
    return ProcessRunResult(
      exitCode: 0,
      stdout: jsonEncode({'frameworkVersion': flutter, 'dartSdkVersion': dart}),
      stderr: '',
    );
  }
}
