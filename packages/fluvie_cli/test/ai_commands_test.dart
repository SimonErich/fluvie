import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fluvie_cli/src/edit_command.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/generate_command.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void _drop(String _) {}

/// The real gate with an empty environment and a nowhere-cache, keeping
/// resolution hermetic while still probing through [runner].
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
    sandbox = Directory.systemTemp.createTempSync('fluvie_cli_ai_sandbox_');
    final outDir = Directory.systemTemp.createTempSync('fluvie_cli_ai_out_');
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

  List<String> capturedFlutterArgv() =>
      verify(
            () => runner.run(
              'flutter',
              captureAny(),
              workingDirectory: any(named: 'workingDirectory'),
            ),
          ).captured.single
          as List<String>;

  Future<Directory> sandboxFactory() async => sandbox;

  group('generate', () {
    Future<int> run(List<String> args) => GenerateCommand(
      runner: runner,
      createSandbox: sandboxFactory,
      resolveFfmpeg: _hermeticResolve,
    ).execute(GenerateCommand.buildParser().parse(args), out: out, err: err);

    test('authors and renders: prompt + spec-out defines, spec reported', () async {
      stubHappyPath();
      final code = await run(['a coffee promo', '--out', outPath, '--project', 'example']);

      expect(code, 0, reason: err.toString());
      final argv = capturedFlutterArgv();
      expect(argv, contains('--dart-define=FLUVIE_AI_PROMPT=a coffee promo'));
      expect(
        argv.singleWhere((a) => a.startsWith('--dart-define=FLUVIE_RENDER_SPEC_OUT=')),
        endsWith('demo.fluvie.json'),
      );
      expect(argv.any((a) => a.contains('FLUVIE_AI_PROVIDER')), isFalse);
      expect(out.toString(), contains(outPath));
      expect(out.toString(), contains('demo.fluvie.json'));
    });

    test('forwards --provider and --spec-out', () async {
      stubHappyPath();
      final specOut = '${sandbox.path}/custom.fluvie.json';
      await run([
        'promo',
        '--out',
        outPath,
        '--project',
        'example',
        '--provider',
        'gemini',
        '--spec-out',
        specOut,
      ]);

      final argv = capturedFlutterArgv();
      expect(argv, contains('--dart-define=FLUVIE_AI_PROVIDER=gemini'));
      expect(argv, contains('--dart-define=FLUVIE_RENDER_SPEC_OUT=$specOut'));
    });

    test('a missing prompt or --out is a usage error (64)', () async {
      expect(await run(['--out', outPath]), 64);
      expect(err.toString(), contains('prompt'));
      err.clear();
      expect(await run(['a promo']), 64);
      expect(err.toString(), contains('--out'));
    });

    test('a bad --frames is a usage error (64)', () async {
      expect(await run(['promo', '--out', outPath, '--frames', 'lots']), 64);
      expect(err.toString(), contains('--frames'));
    });

    test('a capture failure is an operational failure (1)', () async {
      when(
        () => runner.run('ffmpeg', const ['-version']),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''));
      when(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 1, stdout: 'boom', stderr: ''));

      expect(await run(['promo', '--out', outPath, '--project', 'example']), 1);
    });

    test('deriveSpecOut swaps the extension, or appends when none', () {
      expect(GenerateCommand.deriveSpecOut('/tmp/clip.mp4'), '/tmp/clip.fluvie.json');
      expect(GenerateCommand.deriveSpecOut('/tmp/video'), '/tmp/video.fluvie.json');
    });
  });

  group('edit', () {
    late String specPath;
    setUp(() {
      specPath = '${sandbox.path}/in.fluvie.json';
      File(specPath).writeAsStringSync('{"fluvieSpec":1}');
    });

    Future<int> run(List<String> args) => EditCommand(
      runner: runner,
      createSandbox: sandboxFactory,
      resolveFfmpeg: _hermeticResolve,
    ).execute(EditCommand.buildParser().parse(args), out: out, err: err);

    test('loads the base spec and renders: base + change + spec-out defines', () async {
      stubHappyPath();
      final code = await run([
        specPath,
        'make',
        'it',
        'blue',
        '--out',
        outPath,
        '--project',
        'example',
      ]);

      expect(code, 0, reason: err.toString());
      final argv = capturedFlutterArgv();
      expect(argv, contains('--dart-define=FLUVIE_AI_BASE_SPEC=$specPath'));
      expect(argv, contains('--dart-define=FLUVIE_AI_PROMPT=make it blue'));
      // spec-out defaults to overwriting the input spec.
      expect(argv, contains('--dart-define=FLUVIE_RENDER_SPEC_OUT=$specPath'));
    });

    test('a missing spec file is a usage error (64)', () async {
      expect(await run(['/no/such.json', 'change', '--out', outPath]), 64);
      expect(err.toString(), contains('not found'));
    });

    test('too few arguments is a usage error (64)', () async {
      expect(await run([specPath]), 64);
      expect(err.toString(), contains('change'));
    });

    test('an empty change is a usage error (64)', () async {
      expect(await run([specPath, '', '--out', outPath]), 64);
      expect(err.toString(), contains('change'));
    });

    test('a missing --out is a usage error (64)', () async {
      expect(await run([specPath, 'make it blue']), 64);
      expect(err.toString(), contains('--out'));
    });

    test('a bad --frames is a usage error (64)', () async {
      expect(await run([specPath, 'change', '--out', outPath, '--frames', 'x']), 64);
      expect(err.toString(), contains('--frames'));
    });

    test('forwards --provider and surfaces a capture failure (1)', () async {
      when(
        () => runner.run('ffmpeg', const ['-version']),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: _banner8, stderr: ''));
      when(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 1, stdout: 'boom', stderr: ''));

      final code = await run([
        specPath,
        'make it blue',
        '--out',
        outPath,
        '--project',
        'example',
        '--provider',
        'ollama',
      ]);
      expect(code, 1);
    });
  });

  group('render --spec', () {
    Future<int> run(List<String> args) => RenderCommand(
      runner: runner,
      createSandbox: sandboxFactory,
      resolveFfmpeg: _hermeticResolve,
    ).execute(RenderCommand.buildParser().parse(args), out: out, err: err);

    test('passes FLUVIE_RENDER_SPEC and an empty key', () async {
      stubHappyPath();
      final specPath = '${sandbox.path}/in.fluvie.json';
      File(specPath).writeAsStringSync('{"fluvieSpec":1}');

      final code = await run(['--spec', specPath, '--out', outPath, '--project', 'example']);

      expect(code, 0, reason: err.toString());
      final argv = capturedFlutterArgv();
      expect(argv, contains('--dart-define=FLUVIE_RENDER_SPEC=$specPath'));
      expect(argv, contains('--dart-define=FLUVIE_RENDER_KEY='));
    });

    test('a key together with --spec is a usage error (64)', () async {
      final specPath = '${sandbox.path}/in.fluvie.json';
      File(specPath).writeAsStringSync('{"fluvieSpec":1}');
      expect(await run(['demo', '--spec', specPath, '--out', outPath]), 64);
      expect(err.toString(), contains('--spec'));
    });
  });
}
