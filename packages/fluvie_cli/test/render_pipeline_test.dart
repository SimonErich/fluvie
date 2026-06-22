import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void _drop(String _) {}

/// The real gate, but with an empty environment and a nowhere-cache so the
/// resolution stays hermetic (no real `$FLUVIE_FFMPEG`, cache, or network).
Future<String> _hermeticResolve(
  ProcessRunner runner, {
  String? binary,
  bool allowDownload = true,
  ProvisionLog log = _drop,
}) => ensureFfmpeg(
  runner,
  binary: binary,
  allowDownload: allowDownload,
  log: log,
  environment: const {},
  cache: FfmpegCache(abi: Abi.linuxX64, environment: const {}),
);

const _banner8 = 'ffmpeg version 8.0.1 Copyright (c) 2000-2025 the FFmpeg developers';
const _encodeArgs = ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4'];
const ExportFlags _noFlags = (aspect: null, quality: null, format: null, poster: null);

Map<String, Object?> _manifestJson() => {
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
  late String outPath;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    runner = _MockProcessRunner();
    sandbox = Directory.systemTemp.createTempSync('fluvie_pipeline_sandbox_');
    final outDir = Directory.systemTemp.createTempSync('fluvie_pipeline_out_');
    outPath = '${outDir.path}/demo.mp4';
    out = StringBuffer();
    err = StringBuffer();
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
      outDir.deleteSync(recursive: true);
    });
  });

  void stubHappyPath() {
    when(
      () => runner.run('ffmpeg', const ['-version']),
    ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''));
    when(
      () => runner.run(
        'flutter',
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: any(named: 'environment'),
      ),
    ).thenAnswer((_) async {
      File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(64, 0));
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifestJson()));
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
    when(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(64, 0));
      File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifestJson()));
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
    when(
      () => runner.run('ffmpeg', _encodeArgs, workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      File('${sandbox.path}/out.mp4').writeAsBytesSync(const [0, 0, 0, 1]);
      return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
    });
  }

  Future<int> run({
    RenderPipelineOptions options = (
      ffmpegBinary: null,
      projectDir: 'example',
      noCache: false,
      noDownload: false,
      enableImpeller: false,
      verbose: false,
      keepTemp: false,
    ),
    Map<String, String>? environment,
    Map<String, String> extraDefines = const {},
    String harnessPath = 'test/render/capture_harness_test.dart',
    void Function(StringSink out) report = _noop,
  }) => runRenderPipeline(
    runner: runner,
    createSandbox: () async => sandbox,
    options: options,
    key: 'demo',
    outPath: outPath,
    frames: null,
    flags: _noFlags,
    extraDefines: extraDefines,
    environment: environment,
    harnessPath: harnessPath,
    out: out,
    err: err,
    report: report,
    resolveFfmpeg: _hermeticResolve,
  );

  test('probe -> capture -> encode -> wrote, exit 0, sandbox cleaned', () async {
    stubHappyPath();

    final code = await run();

    expect(code, 0, reason: err.toString());
    expect(File(outPath).existsSync(), isTrue);
    expect(out.toString(), contains(outPath));
    expect(sandbox.existsSync(), isFalse);
  });

  test('forwards a per-run environment to the capture (flutter test)', () async {
    stubHappyPath();

    await run(environment: const {'FLUVIE_PROGRESS_FILE': '/tmp/p', 'ANTHROPIC_API_KEY': 'sk'});

    final captured = verify(
      () => runner.run(
        'flutter',
        any(),
        workingDirectory: any(named: 'workingDirectory'),
        environment: captureAny(named: 'environment'),
      ),
    ).captured.single;
    expect(captured, {'FLUVIE_PROGRESS_FILE': '/tmp/p', 'ANTHROPIC_API_KEY': 'sk'});
  });

  test('keepTemp preserves the sandbox and reports where it is', () async {
    stubHappyPath();

    final code = await run(
      options: (
        ffmpegBinary: null,
        projectDir: 'example',
        noCache: false,
        noDownload: false,
        enableImpeller: false,
        verbose: false,
        keepTemp: true,
      ),
    );

    expect(code, 0);
    expect(sandbox.existsSync(), isTrue);
    expect(err.toString(), contains(sandbox.path));
  });

  test('a custom harnessPath flows through to the spawned flutter test', () async {
    stubHappyPath();

    final code = await run(harnessPath: '.fluvie_playground/abc/harness_test.dart');

    expect(code, 0, reason: err.toString());
    final captured =
        verify(
              () => runner.run(
                'flutter',
                captureAny(),
                workingDirectory: any(named: 'workingDirectory'),
                environment: any(named: 'environment'),
              ),
            ).captured.single
            as List<String>;
    expect(captured, contains('.fluvie_playground/abc/harness_test.dart'));
    expect(captured, isNot(contains('test/render/capture_harness_test.dart')));
  });

  test('enableImpeller passes --enable-impeller through to the capture', () async {
    stubHappyPath();

    final code = await run(
      options: (
        ffmpegBinary: null,
        projectDir: 'example',
        noCache: false,
        noDownload: false,
        enableImpeller: true,
        verbose: false,
        keepTemp: false,
      ),
    );

    expect(code, 0, reason: err.toString());
    final captured =
        verify(
              () => runner.run(
                'flutter',
                captureAny(),
                workingDirectory: any(named: 'workingDirectory'),
                environment: any(named: 'environment'),
              ),
            ).captured.single
            as List<String>;
    expect(captured, contains('--enable-impeller'));
  });

  test('the report callback runs after a successful encode', () async {
    stubHappyPath();
    var reported = false;

    await run(report: (sink) => reported = true);

    expect(reported, isTrue);
  });

  test('an ffmpeg below the floor aborts before any capture', () async {
    when(
      () => runner.run('ffmpeg', const ['-version']),
    ).thenAnswer(
      (_) async => const ProcessRunResult(
        exitCode: 0,
        stdout: 'ffmpeg version 5.1.4 Copyright (c) 2000-2023 the FFmpeg developers',
        stderr: '',
      ),
    );

    await expectLater(run(), throwsA(isA<Object>()));
    verifyNever(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    );
  });
}

void _noop(StringSink out) {}
