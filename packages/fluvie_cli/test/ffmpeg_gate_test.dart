import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

const _banner8 = 'ffmpeg version 8.0.1-3ubuntu2 Copyright (c) 2000-2025 the FFmpeg developers';
const _banner5 = 'ffmpeg version 5.1.4-0+deb12u1 Copyright (c) 2000-2023 the FFmpeg developers';
const _bannerGitTag = 'ffmpeg version n7.0 Copyright (c) 2000-2024 the FFmpeg developers';
const _bannerGitMaster =
    'ffmpeg version N-113007-g8d24a28d06 Copyright (c) 2000-2023 the FFmpeg developers\n'
    'built with gcc 12.2.0 (Debian 12.2.0-14)';

void main() {
  late _MockProcessRunner runner;

  setUp(() {
    runner = _MockProcessRunner();
  });

  void stubProbe(String binary, {String banner = _banner8, int exitCode = 0}) {
    when(
      () => runner.run(binary, const ['-version']),
    ).thenAnswer((_) async => ProcessRunResult(exitCode: exitCode, stdout: banner, stderr: ''));
  }

  group('ensureFfmpeg', () {
    test('accepts a >= 6.0 banner from ffmpeg on PATH', () async {
      stubProbe('ffmpeg');
      await expectLater(ensureFfmpeg(runner), completes);
      verify(() => runner.run('ffmpeg', const ['-version'])).called(1);
    });

    test('accepts git-tag banners like n7.0', () async {
      stubProbe('ffmpeg', banner: _bannerGitTag);
      await expectLater(ensureFfmpeg(runner), completes);
    });

    test('an explicit binary overrides the PATH lookup', () async {
      stubProbe('/opt/ffmpeg/bin/ffmpeg');
      await ensureFfmpeg(runner, binary: '/opt/ffmpeg/bin/ffmpeg');
      verify(() => runner.run('/opt/ffmpeg/bin/ffmpeg', const ['-version'])).called(1);
      verifyNever(() => runner.run('ffmpeg', any()));
    });

    test('a version below the 6.0 floor fails with the install hint', () async {
      stubProbe('ffmpeg', banner: _banner5);
      await expectLater(
        () => ensureFfmpeg(runner),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('6.0'))
              .having((e) => e.message, 'message', contains('5.1'))
              .having((e) => e.message, 'message', contains('Install FFmpeg')),
        ),
      );
    });

    test('a git-master banner is rejected, not misparsed from its gcc line', () async {
      stubProbe('ffmpeg', banner: _bannerGitMaster);
      await expectLater(
        () => ensureFfmpeg(runner),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('unparsable'))),
      );
    });

    test('an unparsable banner is rejected with a clear message', () async {
      stubProbe('ffmpeg', banner: 'mystery tool, no version digits here');
      await expectLater(
        () => ensureFfmpeg(runner),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('unparsable'))),
      );
    });

    test('a non-zero probe exit fails with the install hint', () async {
      stubProbe('ffmpeg', exitCode: 127);
      await expectLater(
        () => ensureFfmpeg(runner),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('127'))
              .having((e) => e.message, 'message', contains('Install FFmpeg')),
        ),
      );
    });

    test('a missing binary (ProcessException) fails with the install hint', () async {
      when(
        () => runner.run('ffmpeg', const ['-version']),
      ).thenThrow(const ProcessException('ffmpeg', ['-version'], 'No such file or directory'));
      await expectLater(
        () => ensureFfmpeg(runner),
        throwsA(
          isA<CliFailure>().having((e) => e.message, 'message', contains('Install FFmpeg')),
        ),
      );
    });
  });

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });
}
