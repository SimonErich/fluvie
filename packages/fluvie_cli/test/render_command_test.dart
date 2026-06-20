import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_command.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void _drop(String _) {}

/// The real gate with an empty environment and a nowhere-cache, so the probe
/// still runs through [runner] but resolution never reads the real
/// `$FLUVIE_FFMPEG`, cache, or network.
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

const _banner8 = 'ffmpeg version 8.0.1-3ubuntu2 Copyright (c) 2000-2025 the FFmpeg developers';
const _banner5 = 'ffmpeg version 5.1.4-0+deb12u1 Copyright (c) 2000-2023 the FFmpeg developers';
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
  late _MockProcessRunner runner;
  late Directory sandbox;
  late bool sandboxCreated;
  late String outPath;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    runner = _MockProcessRunner();
    sandbox = Directory.systemTemp.createTempSync('fluvie_cli_cmd_sandbox_');
    sandboxCreated = false;
    final outDir = Directory.systemTemp.createTempSync('fluvie_cli_cmd_out_');
    outPath = '${outDir.path}/demo.mp4';
    out = StringBuffer();
    err = StringBuffer();
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
      outDir.deleteSync(recursive: true);
    });
  });

  RenderCommand command() => RenderCommand(
    runner: runner,
    createSandbox: () async {
      sandboxCreated = true;
      return sandbox;
    },
    resolveFfmpeg: _hermeticResolve,
  );

  Future<int> execute(List<String> args) async =>
      command().execute(RenderCommand.buildParser().parse(args), out: out, err: err);

  void stubProbe({String banner = _banner8, String binary = 'ffmpeg'}) {
    when(
      () => runner.run(binary, const ['-version']),
    ).thenAnswer((_) async => ProcessRunResult(exitCode: 0, stdout: banner, stderr: ''));
  }

  void stubCapture({
    int exitCode = 0,
    String stdout = '',
    bool writesManifest = true,
    bool writesFrames = true,
  }) {
    when(
      () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      if (writesFrames) {
        File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(64, 0));
      }
      if (writesManifest) {
        File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(_manifestJson()));
      }
      return ProcessRunResult(exitCode: exitCode, stdout: stdout, stderr: '');
    });
  }

  void stubEncode({int exitCode = 0, String binary = 'ffmpeg'}) {
    when(
      () => runner.run(binary, _encodeArgs, workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async {
      if (exitCode == 0) {
        File('${sandbox.path}/out.mp4').writeAsBytesSync(const [0, 0, 0, 1]);
      }
      return ProcessRunResult(exitCode: exitCode, stdout: '', stderr: '');
    });
  }

  group('RenderCommand image sequence', () {
    const seqArgs = [
      '-f',
      'rawvideo',
      '-i',
      'frames.rgba',
      '-c:v',
      'png',
      '-f',
      'image2',
      'frame_%06d.png',
    ];

    void stubSeqCapture() {
      when(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async {
        File('${sandbox.path}/frames.rgba').writeAsBytesSync(List.filled(64, 0));
        final json = _manifestJson()
          ..['outputFileName'] = 'frame_%06d.png'
          ..['ffmpegArgs'] = seqArgs;
        File('${sandbox.path}/manifest.json').writeAsStringSync(jsonEncode(json));
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
    }

    void stubSeqEncode({int stills = 3}) {
      when(
        () => runner.run('ffmpeg', seqArgs, workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async {
        for (var i = 0; i < stills; i++) {
          final name = 'frame_${i.toString().padLeft(6, '0')}.png';
          File('${sandbox.path}/$name').writeAsBytesSync([i]);
        }
        return const ProcessRunResult(exitCode: 0, stdout: '', stderr: '');
      });
    }

    test('--format imageSequence collects every still into the --out directory', () async {
      stubProbe();
      stubSeqCapture();
      stubSeqEncode(stills: 4);
      final outDir = Directory.systemTemp.createTempSync('fluvie_cli_seq_out_');
      addTearDown(() => outDir.deleteSync(recursive: true));
      final seqOut = '${outDir.path}/frames';

      final code = await execute([
        'demo',
        '--out',
        seqOut,
        '--project',
        'example',
        '--format',
        'imageSequence',
      ]);

      expect(code, 0, reason: err.toString());
      final landed = Directory(
        seqOut,
      ).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList()..sort();
      expect(landed, [
        'frame_000000.png',
        'frame_000001.png',
        'frame_000002.png',
        'frame_000003.png',
      ]);
      expect(out.toString(), contains(seqOut));
      expect(sandbox.existsSync(), isFalse, reason: 'the sandbox is cleaned up');
    });
  });

  group('RenderCommand happy path', () {
    test('probe -> capture -> encode -> move -> cleanup, exit 0', () async {
      stubProbe();
      stubCapture();
      stubEncode();

      final code = await execute(['demo', '--out', outPath, '--project', 'example']);

      expect(code, 0, reason: err.toString());
      verifyInOrder([
        () => runner.run('ffmpeg', const ['-version']),
        () => runner.run('flutter', any(), workingDirectory: 'example'),
        () => runner.run('ffmpeg', _encodeArgs, workingDirectory: sandbox.path),
      ]);
      expect(File(outPath).existsSync(), isTrue);
      expect(sandbox.existsSync(), isFalse, reason: 'the sandbox is cleaned up');
      expect(out.toString(), contains(outPath));
    });

    test('passes the exact flutter-test argv including the dart-defines', () async {
      stubProbe();
      stubCapture();
      stubEncode();

      await execute([
        'demo',
        '--out',
        outPath,
        '--project',
        'example',
        '--frames',
        '8',
        '--no-cache',
      ]);

      verify(
        () => runner.run('flutter', [
          'test',
          '--no-pub',
          'test/render/capture_harness_test.dart',
          '--dart-define=FLUVIE_RENDER_KEY=demo',
          '--dart-define=FLUVIE_RENDER_OUT_DIR=${sandbox.path}',
          '--dart-define=FLUVIE_RENDER_FRAMES=8',
          '--dart-define=FLUVIE_RENDER_NO_CACHE=true',
        ], workingDirectory: 'example'),
      ).called(1);
    });

    test('without --project the example project is auto-discovered', () async {
      stubProbe();
      stubCapture();
      stubEncode();

      final code = await execute(['demo', '--out', outPath]);

      expect(code, 0, reason: err.toString());
      final captured = verify(
        () => runner.run('flutter', any(), workingDirectory: captureAny(named: 'workingDirectory')),
      ).captured;
      expect(captured.single, endsWith('/example'));
    });

    test('--ffmpeg routes both the probe and the encode to the explicit binary', () async {
      stubProbe(binary: '/opt/ffmpeg');
      stubCapture();
      stubEncode(binary: '/opt/ffmpeg');

      final code = await execute([
        'demo',
        '--out',
        outPath,
        '--project',
        'example',
        '--ffmpeg',
        '/opt/ffmpeg',
      ]);

      expect(code, 0, reason: err.toString());
      verifyNever(() => runner.run('ffmpeg', any()));
    });

    test('--keep-temp preserves the sandbox and says where it is', () async {
      stubProbe();
      stubCapture();
      stubEncode();

      final code = await execute(['demo', '--out', outPath, '--project', 'example', '--keep-temp']);

      expect(code, 0);
      expect(sandbox.existsSync(), isTrue);
      expect(err.toString(), contains(sandbox.path));
    });
  });

  group('RenderCommand failures', () {
    test('an old ffmpeg with --no-download aborts before any capture or sandbox', () async {
      stubProbe(banner: _banner5);

      final code = await execute([
        'demo',
        '--out',
        outPath,
        '--project',
        'example',
        '--no-download',
      ]);

      expect(code, 1);
      expect(err.toString(), contains('6.0'));
      expect(sandboxCreated, isFalse, reason: 'fail-fast happens before createTemp');
      verifyNever(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      );
    });

    test('a failing capture surfaces its output and skips the encode', () async {
      stubProbe();
      stubCapture(
        exitCode: 1,
        stdout: 'Unknown composition key "nope". Known keys: [demo]',
        writesManifest: false,
        writesFrames: false,
      );

      final code = await execute(['nope', '--out', outPath, '--project', 'example']);

      expect(code, 1);
      expect(err.toString(), contains('Unknown composition key'));
      verifyNever(() => runner.run('ffmpeg', _encodeArgs, workingDirectory: sandbox.path));
      expect(sandbox.existsSync(), isFalse, reason: 'cleanup still runs on failure');
    });

    test('a missing flutter binary is exit 1 with a hint, not a raw exception', () async {
      stubProbe();
      when(
        () => runner.run('flutter', any(), workingDirectory: any(named: 'workingDirectory')),
      ).thenThrow(const ProcessException('flutter', ['test'], 'No such file or directory'));

      final code = await execute(['demo', '--out', outPath, '--project', 'example']);

      expect(code, 1);
      expect(err.toString(), contains('flutter'));
      expect(err.toString(), contains('PATH'));
      verifyNever(() => runner.run('ffmpeg', _encodeArgs, workingDirectory: sandbox.path));
    });

    test('a capture that never writes the manifest is a capture failure', () async {
      stubProbe();
      stubCapture(writesManifest: false);

      final code = await execute(['demo', '--out', outPath, '--project', 'example']);

      expect(code, 1);
      expect(err.toString(), contains('manifest.json'));
      verifyNever(() => runner.run('ffmpeg', _encodeArgs, workingDirectory: sandbox.path));
    });

    test('missing --out is a usage error (64)', () async {
      final code = await execute(['demo']);

      expect(code, 64);
      expect(err.toString(), contains('--out'));
      verifyNever(() => runner.run(any(), any()));
    });

    test('a missing key is a usage error (64)', () async {
      final code = await execute(['--out', outPath]);

      expect(code, 64);
      expect(err.toString(), contains('composition key'));
    });

    test('a non-integer --frames is a usage error (64)', () async {
      final code = await execute(['demo', '--out', outPath, '--frames', 'many']);

      expect(code, 64);
      expect(err.toString(), contains('--frames'));
    });

    test('an unknown --aspect is a usage error naming the valid set', () async {
      final code = await execute(['demo', '--out', outPath, '--aspect', 'widescreen']);

      expect(code, 64);
      expect(err.toString(), contains('--aspect'));
      expect(err.toString(), contains('reels'));
      expect(err.toString(), contains('square'));
      expect(err.toString(), contains('landscape'));
      expect(err.toString(), contains('portrait45'));
      verifyNever(() => runner.run(any(), any()));
    });

    test('an unknown --quality is a usage error naming the valid set', () async {
      final code = await execute(['demo', '--out', outPath, '--quality', 'ultra']);

      expect(code, 64);
      expect(err.toString(), contains('--quality'));
      expect(err.toString(), contains('low'));
      expect(err.toString(), contains('max'));
    });

    test('an unknown --format is a usage error naming the valid set', () async {
      final code = await execute(['demo', '--out', outPath, '--format', 'avi']);

      expect(code, 64);
      expect(err.toString(), contains('--format'));
      expect(err.toString(), contains('mp4'));
      expect(err.toString(), contains('gif'));
      expect(err.toString(), contains('imageSequence'));
      expect(err.toString(), contains('transparent'));
    });

    test('an empty --poster is a usage error', () async {
      final code = await execute(['demo', '--out', outPath, '--poster', '']);

      expect(code, 64);
      expect(err.toString(), contains('--poster'));
    });
  });

  group('RenderCommand export flags', () {
    test('the validated aspect/quality/format/poster become dart-defines', () async {
      stubProbe();
      stubCapture();
      stubEncode();

      await execute([
        'demo',
        '--out',
        outPath,
        '--project',
        'example',
        '--aspect',
        'square',
        '--quality',
        'max',
        '--format',
        'gif',
        '--poster',
        '1.5s',
      ]);

      final captured =
          verify(
                () => runner.run(
                  'flutter',
                  captureAny(),
                  workingDirectory: any(named: 'workingDirectory'),
                ),
              ).captured.single
              as List<String>;
      expect(captured, contains('--dart-define=FLUVIE_RENDER_ASPECT=square'));
      expect(captured, contains('--dart-define=FLUVIE_RENDER_QUALITY=max'));
      expect(captured, contains('--dart-define=FLUVIE_RENDER_FORMAT=gif'));
      expect(captured, contains('--dart-define=FLUVIE_RENDER_POSTER=1.5s'));
    });

    test('a plain render forwards none of the new defines', () async {
      stubProbe();
      stubCapture();
      stubEncode();

      await execute(['demo', '--out', outPath, '--project', 'example']);

      final captured =
          verify(
                () => runner.run(
                  'flutter',
                  captureAny(),
                  workingDirectory: any(named: 'workingDirectory'),
                ),
              ).captured.single
              as List<String>;
      expect(captured.any((a) => a.contains('FLUVIE_RENDER_ASPECT')), isFalse);
      expect(captured.any((a) => a.contains('FLUVIE_RENDER_FORMAT')), isFalse);
    });
  });

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });
}
