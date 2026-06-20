import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:mocktail/mocktail.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

const _banner8 = 'ffmpeg version 8.0.1-3ubuntu2 Copyright (c) 2000-2025 the FFmpeg developers';
const _banner5 = 'ffmpeg version 5.1.4-0+deb12u1 Copyright (c) 2000-2023 the FFmpeg developers';

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  late _MockProcessRunner runner;
  final sandbox = Directory('/tmp/fluvie_test_sandbox');
  const encodeArgs = ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4'];

  setUp(() {
    runner = _MockProcessRunner();
  });

  /// Stubs the `-version` probe for [binary] to answer [banner].
  void stubProbe(String binary, {String banner = _banner8, int exitCode = 0}) {
    when(
      () => runner.run(binary, const ['-version']),
    ).thenAnswer((_) async => ProcessRunResult(exitCode: exitCode, stdout: banner, stderr: ''));
  }

  /// Stubs the encode run for [binary].
  void stubEncode(String binary, {int exitCode = 0, String stderr = ''}) {
    when(
      () => runner.run(binary, encodeArgs, workingDirectory: any(named: 'workingDirectory')),
    ).thenAnswer((_) async => ProcessRunResult(exitCode: exitCode, stdout: '', stderr: stderr));
  }

  group('ProcessFfmpegProvider.probeVersion', () {
    test('parses the real-world banner shape', () async {
      stubProbe('ffmpeg');
      final provider = ProcessFfmpegProvider(runner: runner, environment: const {});
      final version = await provider.probeVersion();
      expect(version, isNotNull);
      expect(version!.major, 8);
      expect(version.minor, 0);
    });

    test('unparsable banner throws a typed error advising binaryPath', () async {
      stubProbe('ffmpeg', banner: 'mystery tool, no version here');
      final provider = ProcessFfmpegProvider(runner: runner, environment: const {});
      expect(
        provider.probeVersion,
        throwsA(
          isA<FluvieEncodeException>().having(
            (e) => e.message,
            'message',
            contains('binaryPath'),
          ),
        ),
      );
    });

    test('failed probe run throws a typed error with the exit code', () async {
      stubProbe('ffmpeg', exitCode: 127);
      final provider = ProcessFfmpegProvider(runner: runner, environment: const {});
      expect(
        provider.probeVersion,
        throwsA(isA<FluvieEncodeException>().having((e) => e.exitCode, 'exitCode', 127)),
      );
    });
  });

  group('ProcessFfmpegProvider binary resolution', () {
    test('defaults to "ffmpeg" on PATH', () async {
      stubProbe('ffmpeg');
      await ProcessFfmpegProvider(runner: runner, environment: const {}).probeVersion();
      verify(() => runner.run('ffmpeg', const ['-version'])).called(1);
    });

    test('FLUVIE_FFMPEG environment variable overrides PATH lookup', () async {
      stubProbe('/opt/ffmpeg/bin/ffmpeg');
      final provider = ProcessFfmpegProvider(
        runner: runner,
        environment: const {'FLUVIE_FFMPEG': '/opt/ffmpeg/bin/ffmpeg'},
      );
      await provider.probeVersion();
      verify(() => runner.run('/opt/ffmpeg/bin/ffmpeg', const ['-version'])).called(1);
    });

    test('an explicit binaryPath beats the environment variable', () async {
      stubProbe('/explicit/ffmpeg');
      final provider = ProcessFfmpegProvider(
        runner: runner,
        binaryPath: '/explicit/ffmpeg',
        environment: const {'FLUVIE_FFMPEG': '/env/ffmpeg'},
      );
      await provider.probeVersion();
      verify(() => runner.run('/explicit/ffmpeg', const ['-version'])).called(1);
      verifyNever(() => runner.run('/env/ffmpeg', any()));
    });

    test('falls back to the managed cache build when present', () async {
      final cacheRoot = Directory.systemTemp.createTempSync('fluvie_provider_cache_');
      addTearDown(() => cacheRoot.deleteSync(recursive: true));
      final cached = File('${cacheRoot.path}/fluvie/ffmpeg/8.1/ffmpeg')
        ..createSync(recursive: true)
        ..writeAsStringSync('stub');
      stubProbe(cached.path);

      final provider = ProcessFfmpegProvider(
        runner: runner,
        environment: {'XDG_CACHE_HOME': cacheRoot.path},
      );
      await provider.probeVersion();

      verify(() => runner.run(cached.path, const ['-version'])).called(1);
      verifyNever(() => runner.run('ffmpeg', any()));
    });

    test('ignores a managed cache that is not installed', () async {
      final cacheRoot = Directory.systemTemp.createTempSync('fluvie_provider_nocache_');
      addTearDown(() => cacheRoot.deleteSync(recursive: true));
      stubProbe('ffmpeg');

      final provider = ProcessFfmpegProvider(
        runner: runner,
        environment: {'XDG_CACHE_HOME': cacheRoot.path},
      );
      await provider.probeVersion();

      verify(() => runner.run('ffmpeg', const ['-version'])).called(1);
    });
  });

  group('ProcessFfmpegProvider.encode', () {
    test('passes the exact argument array through untouched', () async {
      stubProbe('ffmpeg');
      stubEncode('ffmpeg');
      final provider = ProcessFfmpegProvider(runner: runner, environment: const {});
      await provider.encode(args: encodeArgs, sandbox: sandbox);
      // Pinning workingDirectory to the sandbox keeps the probe call (which
      // passes none) out of the capture.
      final captured = verify(
        () => runner.run('ffmpeg', captureAny(), workingDirectory: sandbox.path),
      ).captured;
      expect(captured, [encodeArgs]);
    });

    test('runs with the sandbox as working directory', () async {
      stubProbe('ffmpeg');
      stubEncode('ffmpeg');
      final provider = ProcessFfmpegProvider(runner: runner, environment: const {});
      await provider.encode(args: encodeArgs, sandbox: sandbox);
      verify(
        () => runner.run('ffmpeg', encodeArgs, workingDirectory: sandbox.path),
      ).called(1);
    });

    test('a version below the floor aborts before any encode run', () async {
      stubProbe('ffmpeg', banner: _banner5);
      final provider = ProcessFfmpegProvider(runner: runner, environment: const {});
      await expectLater(
        () => provider.encode(args: encodeArgs, sandbox: sandbox),
        throwsA(
          isA<FluvieEncodeException>().having((e) => e.message, 'message', contains('6.0')),
        ),
      );
      verifyNever(
        () => runner.run(any(), encodeArgs, workingDirectory: any(named: 'workingDirectory')),
      );
    });

    test('a non-zero exit throws FluvieEncodeException carrying the stderr tail', () async {
      stubProbe('ffmpeg');
      stubEncode('ffmpeg', exitCode: 69, stderr: 'Packet too small (100)');
      final provider = ProcessFfmpegProvider(runner: runner, environment: const {});
      await expectLater(
        () => provider.encode(args: encodeArgs, sandbox: sandbox),
        throwsA(
          isA<FluvieEncodeException>()
              .having((e) => e.exitCode, 'exitCode', 69)
              .having((e) => e.stderrTail, 'stderrTail', contains('Packet too small')),
        ),
      );
    });

    test('stderr longer than 4 KiB keeps only the tail', () async {
      final longStderr = '${'x' * 5000}TAIL_MARKER';
      stubProbe('ffmpeg');
      stubEncode('ffmpeg', exitCode: 1, stderr: longStderr);
      final provider = ProcessFfmpegProvider(runner: runner, environment: const {});
      await expectLater(
        () => provider.encode(args: encodeArgs, sandbox: sandbox),
        throwsA(
          isA<FluvieEncodeException>().having(
            (e) => e.stderrTail,
            'stderrTail',
            allOf(hasLength(4096), endsWith('TAIL_MARKER')),
          ),
        ),
      );
    });
  });
}
