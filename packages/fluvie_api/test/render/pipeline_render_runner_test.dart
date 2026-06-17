import 'dart:convert';
import 'dart:io';

import 'package:fluvie_api/src/render/pipeline_render_runner.dart';
import 'package:fluvie_api/src/render/render_request.dart';
import 'package:fluvie_api/src/render/render_runner.dart';
import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

const _banner8 = 'ffmpeg version 8.0.1 Copyright (c) 2000-2025 the FFmpeg developers';
const _encodeArgs = ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4'];

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
  late Directory sandbox;
  late Directory workDir;

  setUp(() {
    runner = _MockProcessRunner();
    sandbox = Directory.systemTemp.createTempSync('fluvie_api_sandbox_');
    workDir = Directory.systemTemp.createTempSync('fluvie_api_work_');
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
      workDir.deleteSync(recursive: true);
    });
  });

  PipelineRenderRunner makeRunner({Map<String, String> aiEnv = const {}}) => PipelineRenderRunner(
    renderProject: 'example',
    aiEnv: aiEnv,
    processRunner: runner,
    createSandbox: () async => sandbox,
  );

  void stubProbe() {
    when(
      () => runner.run('ffmpeg', const ['-version']),
    ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''));
  }

  void stubCapture({void Function(Map<String, String>? env)? onCall}) {
    when(
      () => runner.run(
        'flutter',
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((invocation) async {
      onCall?.call(invocation.namedArguments[#environment] as Map<String, String>?);
      File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(8, 0));
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifest()));
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
  }

  void stubEncode() {
    when(
      () => runner.run('ffmpeg', _encodeArgs, workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      File('${sandbox.path}/out.mp4').writeAsBytesSync(const [0, 0, 0, 1]);
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
  }

  test('renders a key request, producing the video in the work dir', () async {
    stubProbe();
    stubCapture();
    stubEncode();

    final outcome = await makeRunner().run(
      const KeyRenderRequest('demo', (format: null, aspect: null, quality: null, poster: null)),
      workDir: workDir,
    );

    expect(outcome.videoContentType, 'video/mp4');
    expect(File(outcome.videoPath).existsSync(), isTrue);
    expect(outcome.videoPath, '${workDir.path}/video.mp4');
    expect(outcome.posterPath, isNull);
    expect(outcome.specPath, isNull);
  });

  test('a spec request writes the spec file and passes FLUVIE_RENDER_SPEC', () async {
    stubProbe();
    late List<String> argv;
    when(
      () => runner.run(
        'flutter',
        captureAny(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((invocation) async {
      argv = invocation.positionalArguments[1] as List<String>;
      File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(8, 0));
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifest()));
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
    stubEncode();

    await makeRunner().run(
      const SpecRenderRequest(
        {
          'scenes': [
            {'duration': '1s'},
          ],
        },
        (format: null, aspect: null, quality: null, poster: null),
      ),
      workDir: workDir,
    );

    expect(File('${workDir.path}/input.fluvie.json').existsSync(), isTrue);
    expect(argv.any((a) => a.startsWith('--dart-define=FLUVIE_RENDER_SPEC=')), isTrue);
  });

  test('an edit request writes the base spec and passes FLUVIE_AI_BASE_SPEC', () async {
    stubProbe();
    late List<String> argv;
    when(
      () => runner.run(
        'flutter',
        captureAny(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((invocation) async {
      argv = invocation.positionalArguments[1] as List<String>;
      File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(8, 0));
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifest()));
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
    stubEncode();

    await makeRunner().run(
      const EditRenderRequest(
        {
          'scenes': [
            {'duration': '1s'},
          ],
        },
        'make it blue',
        null,
        (format: null, aspect: null, quality: null, poster: null),
      ),
      workDir: workDir,
    );

    expect(File('${workDir.path}/base.fluvie.json').existsSync(), isTrue);
    expect(argv.any((a) => a.startsWith('--dart-define=FLUVIE_AI_BASE_SPEC=')), isTrue);
    expect(argv.any((a) => a.contains('FLUVIE_AI_PROMPT=make it blue')), isTrue);
  });

  test('forwards the AI env and progress file, and reports progress', () async {
    stubProbe();
    Map<String, String>? captured;
    stubCapture(
      onCall: (env) {
        captured = env;
        final file = env?['FLUVIE_PROGRESS_FILE'];
        if (file != null) File(file).writeAsStringSync('48/48');
      },
    );
    stubEncode();
    final reported = <RenderProgress>[];

    await makeRunner(aiEnv: const {'ANTHROPIC_API_KEY': 'sk'}).run(
      const PromptRenderRequest(
        'a promo',
        'gemini',
        (format: null, aspect: null, quality: null, poster: null),
      ),
      workDir: workDir,
      onProgress: reported.add,
    );

    expect(captured!['ANTHROPIC_API_KEY'], 'sk');
    expect(captured!.containsKey('FLUVIE_PROGRESS_FILE'), isTrue);
    expect(reported, contains(const RenderProgress(completed: 48, total: 48)));
  });

  test('maps a CliFailure from a failed capture to a RenderFailure', () async {
    stubProbe();
    when(
      () => runner.run(
        'flutter',
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async => const ProcessRunResult(exitCode: 1, stdout: 'boom', stderr: ''));

    expect(
      makeRunner().run(
        const KeyRenderRequest('demo', (format: null, aspect: null, quality: null, poster: null)),
        workDir: workDir,
      ),
      throwsA(isA<RenderFailure>()),
    );
  });

  test('a transparent format maps to a webm content type', () async {
    stubProbe();
    stubCapture();
    stubEncode();

    final outcome = await makeRunner().run(
      const KeyRenderRequest(
        'demo',
        (format: 'transparent', aspect: null, quality: null, poster: null),
      ),
      workDir: workDir,
    );
    expect(outcome.videoContentType, 'video/webm');
  });
}
