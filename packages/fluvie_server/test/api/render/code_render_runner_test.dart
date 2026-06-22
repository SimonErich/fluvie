import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:fluvie_server/src/api/render/pipeline_render_runner.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

const _banner8 = 'ffmpeg version 8.0.1 Copyright (c) 2000-2025 the FFmpeg developers';
const _encodeArgs = ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4'];
const ExportOptions _noOpts = (format: null, aspect: null, quality: null, poster: null);
const String _goodCode = '''
import 'package:fluvie/fluvie.dart';

Video build() => Video(scenes: [Scene(duration: Time.seconds(1), children: const [])]);
''';

Map<String, Object?> _manifest() => {
  'schemaVersion': 1,
  'width': 320,
  'height': 240,
  'fps': 30,
  'frameCount': 48,
  'framesFileName': 'frames.rgba',
  'outputFileName': 'out.mp4',
  'renderDigest': 'cbf29ce484222325',
  'ffmpegArgs': _encodeArgs,
};

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  late _MockProcessRunner runner;
  late Directory project;
  late Directory sandbox;
  late Directory workDir;

  setUp(() {
    runner = _MockProcessRunner();
    project = Directory.systemTemp.createTempSync('fluvie_code_project_');
    // The harness helper the generated test imports must exist for a real run;
    // resolveProjectDir also needs the marker file. Stub both.
    File(
      '${project.path}/test/render/capture_harness_test.dart',
    ).createSync(recursive: true);
    File('${project.path}/test/render/render_harness.dart').createSync(recursive: true);
    sandbox = Directory.systemTemp.createTempSync('fluvie_code_sandbox_');
    workDir = Directory.systemTemp.createTempSync('fluvie_code_work_');
    addTearDown(() {
      for (final dir in [project, sandbox, workDir]) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  });

  PipelineRenderRunner makeRunner({Map<String, String> aiEnv = const {}}) => PipelineRenderRunner(
    renderProject: project.path,
    aiEnv: aiEnv,
    processRunner: runner,
    createSandbox: () async => sandbox,
  );

  void stubProbe() {
    when(
      () => runner.run('ffmpeg', const ['-version']),
    ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''));
  }

  void stubEncode() {
    when(
      () => runner.run('ffmpeg', _encodeArgs, workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      File('${sandbox.path}/out.mp4').writeAsBytesSync(const [0, 0, 0, 1]);
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
  }

  // Captures the argv + environment and the harness file as it existed at spawn
  // time (the runner deletes it in finally, so we must read it during the call).
  late List<String> argv;
  late Map<String, String>? env;
  String? harnessAtSpawn;
  String? inputAtSpawn;

  void stubCapture() {
    when(
      () => runner.run(
        'flutter',
        captureAny(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((invocation) async {
      argv = invocation.positionalArguments[1] as List<String>;
      env = invocation.namedArguments[#environment] as Map<String, String>?;
      final dir = Directory('${project.path}/.fluvie_playground');
      final genDir = dir.listSync().whereType<Directory>().single;
      harnessAtSpawn = File('${genDir.path}/harness_test.dart').readAsStringSync();
      inputAtSpawn = File('${genDir.path}/input.dart').readAsStringSync();
      File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(8, 0));
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifest()));
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
  }

  test('writes input.dart + a generated harness and renders the snippet', () async {
    stubProbe();
    stubCapture();
    stubEncode();

    final outcome = await makeRunner().run(
      const CodeRenderRequest(_goodCode, _noOpts),
      workDir: workDir,
    );

    expect(inputAtSpawn, _goodCode);
    expect(harnessAtSpawn, contains("import 'input.dart' as user;"));
    expect(harnessAtSpawn, contains('compositionFromVideo(user.build)'));
    expect(outcome.videoContentType, 'video/mp4');
    expect(File(outcome.videoPath).existsSync(), isTrue);
    expect(outcome.specPath, isNull);
  });

  test('runs flutter test against the generated harness path under the project', () async {
    stubProbe();
    stubCapture();
    stubEncode();

    await makeRunner().run(const CodeRenderRequest(_goodCode, _noOpts), workDir: workDir);

    final harnessArg = argv.firstWhere((a) => a.endsWith('harness_test.dart'));
    expect(harnessArg, startsWith('.fluvie_playground/'));
    expect(argv, isNot(contains('test/render/capture_harness_test.dart')));
    // The shared frame cache keys on the "code" composition key, not the
    // snippet, so code renders must bypass it (one submission's frames must
    // never be served for another).
    expect(argv, contains('--dart-define=FLUVIE_RENDER_NO_CACHE=true'));
  });

  test('strips the AI env for a code render (no secrets reach untrusted code)', () async {
    stubProbe();
    stubCapture();
    stubEncode();

    await makeRunner(aiEnv: const {'ANTHROPIC_API_KEY': 'sk'}).run(
      const CodeRenderRequest(_goodCode, _noOpts),
      workDir: workDir,
    );

    expect(env?.containsKey('ANTHROPIC_API_KEY'), isFalse);
  });

  test('deletes the per-render directory after a successful render', () async {
    stubProbe();
    stubCapture();
    stubEncode();

    await makeRunner().run(const CodeRenderRequest(_goodCode, _noOpts), workDir: workDir);

    final dir = Directory('${project.path}/.fluvie_playground');
    expect(dir.existsSync() ? dir.listSync() : const <FileSystemEntity>[], isEmpty);
  });

  test('deletes the per-render directory even when the capture fails', () async {
    stubProbe();
    when(
      () => runner.run(
        'flutter',
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => const ProcessRunResult(exitCode: 1, stdout: 'boom', stderr: ''));

    await expectLater(
      makeRunner().run(const CodeRenderRequest(_goodCode, _noOpts), workDir: workDir),
      throwsA(isA<RenderFailure>()),
    );

    final dir = Directory('${project.path}/.fluvie_playground');
    expect(dir.existsSync() ? dir.listSync() : const <FileSystemEntity>[], isEmpty);
  });

  test('a capture that exceeds the wall-clock timeout fails as a RenderFailure', () async {
    stubProbe();
    when(
      () => runner.run(
        'flutter',
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async {
      // Simulate a runaway capture: never completes within the timeout.
      await Future<void>.delayed(const Duration(seconds: 30));
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });

    final timed = PipelineRenderRunner(
      renderProject: project.path,
      processRunner: runner,
      createSandbox: () async => sandbox,
      captureTimeout: const Duration(milliseconds: 200),
    );

    await expectLater(
      timed.run(const CodeRenderRequest(_goodCode, _noOpts), workDir: workDir),
      throwsA(isA<RenderFailure>().having((e) => e.message, 'message', contains('timed out'))),
    );
    // The staging directory is still cleaned up after a timeout.
    final dir = Directory('${project.path}/.fluvie_playground');
    expect(dir.existsSync() ? dir.listSync() : const <FileSystemEntity>[], isEmpty);
  });

  test('rejects a disallowed import before spawning flutter (defense in depth)', () async {
    stubProbe();
    stubCapture();
    stubEncode();

    await expectLater(
      makeRunner().run(
        const CodeRenderRequest("import 'dart:io';\nVideo build() => throw 0;", _noOpts),
        workDir: workDir,
      ),
      throwsA(
        isA<RenderFailure>().having((e) => e.message, 'message', contains('dart:io')),
      ),
    );
    verifyNever(
      () => runner.run(
        'flutter',
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    );
  });
}
