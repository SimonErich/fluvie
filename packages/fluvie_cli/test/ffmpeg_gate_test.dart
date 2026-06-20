import 'dart:ffi';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

/// A fake installer that records whether it ran and returns a fixed path.
final class _FakeInstaller implements FfmpegInstaller {
  int calls = 0;

  @override
  Future<String> install({bool force = false, ProvisionLog log = _drop}) async {
    calls++;
    log('downloading...');
    return '/cache/fluvie/ffmpeg/8.1/ffmpeg';
  }

  static void _drop(String _) {}
}

const _banner8 = 'ffmpeg version 8.0.1-3ubuntu2 Copyright (c) 2000-2025 the FFmpeg developers';
const _banner5 = 'ffmpeg version 5.1.4-0+deb12u1 Copyright (c) 2000-2023 the FFmpeg developers';
const _bannerGitTag = 'ffmpeg version n7.0 Copyright (c) 2000-2024 the FFmpeg developers';
const _bannerGitMaster =
    'ffmpeg version N-113007-g8d24a28d06 Copyright (c) 2000-2023 the FFmpeg developers\n'
    'built with gcc 12.2.0 (Debian 12.2.0-14)';

/// A cache that resolves nowhere, so resolution skips the managed-cache step.
FfmpegCache get _noCache => FfmpegCache(abi: Abi.linuxX64, environment: const <String, String>{});

void main() {
  late _MockProcessRunner runner;

  setUpAll(() => registerFallbackValue(<String>[]));
  setUp(() => runner = _MockProcessRunner());

  void stubProbe(String binary, {String banner = _banner8, int exitCode = 0}) {
    when(
      () => runner.run(binary, const ['-version']),
    ).thenAnswer((_) async => ProcessRunResult(exitCode: exitCode, stdout: banner, stderr: ''));
  }

  Future<String> resolve({
    String? binary,
    bool allowDownload = true,
    FfmpegInstaller? provisioner,
    Map<String, String> environment = const {},
    FfmpegCache? cache,
  }) => ensureFfmpeg(
    runner,
    binary: binary,
    allowDownload: allowDownload,
    provisioner: provisioner,
    environment: environment,
    cache: cache ?? _noCache,
  );

  group('ensureFfmpeg resolution order', () {
    test('returns "ffmpeg" when a >= 6.0 binary is on PATH', () async {
      stubProbe('ffmpeg');
      expect(await resolve(), 'ffmpeg');
    });

    test('accepts git-tag banners like n7.0 on PATH', () async {
      stubProbe('ffmpeg', banner: _bannerGitTag);
      expect(await resolve(), 'ffmpeg');
    });

    test('an explicit --ffmpeg wins and is returned verbatim', () async {
      stubProbe('/opt/ffmpeg/bin/ffmpeg');
      expect(await resolve(binary: '/opt/ffmpeg/bin/ffmpeg'), '/opt/ffmpeg/bin/ffmpeg');
      verifyNever(() => runner.run('ffmpeg', any()));
    });

    test(r'$FLUVIE_FFMPEG is used when no flag is given', () async {
      stubProbe('/env/ffmpeg');
      expect(
        await resolve(environment: const {'FLUVIE_FFMPEG': '/env/ffmpeg'}),
        '/env/ffmpeg',
      );
    });

    test('a bad explicit binary is fatal and never triggers a download', () async {
      stubProbe('/bad/ffmpeg', banner: _banner5);
      final installer = _FakeInstaller();
      await expectLater(
        () => resolve(binary: '/bad/ffmpeg', provisioner: installer),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('5.1'))
              .having((e) => e.message, 'message', contains('fluvie ffmpeg install')),
        ),
      );
      expect(installer.calls, 0);
    });

    test('uses the real environment and cache by default (explicit short-circuits)', () async {
      stubProbe('/x');
      expect(await ensureFfmpeg(runner, binary: '/x'), '/x');
    });

    test('a probe that cannot spawn the binary is reported as a failure', () async {
      when(
        () => runner.run('ffmpeg', const ['-version']),
      ).thenThrow(const ProcessException('ffmpeg', ['-version'], 'No such file'));
      await expectLater(
        () => resolve(allowDownload: false),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('could not run'))),
      );
    });

    test('prefers the managed cache build over PATH', () async {
      final dir = Directory.systemTemp.createTempSync('fluvie_gate_cache_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cache = FfmpegCache(abi: Abi.linuxX64, environment: {'XDG_CACHE_HOME': dir.path});
      File(cache.binaryPath!)
        ..createSync(recursive: true)
        ..writeAsStringSync('stub');
      stubProbe(cache.binaryPath!);
      stubProbe('ffmpeg');

      expect(await resolve(cache: cache), cache.binaryPath);
      verifyNever(() => runner.run('ffmpeg', any()));
    });
  });

  group('ensureFfmpeg auto-provision', () {
    test('downloads the pinned build when nothing usable resolves', () async {
      stubProbe('ffmpeg', exitCode: 127);
      final installer = _FakeInstaller();
      expect(await resolve(provisioner: installer), '/cache/fluvie/ffmpeg/8.1/ffmpeg');
      expect(installer.calls, 1);
    });

    test('an old PATH ffmpeg falls through to a download', () async {
      stubProbe('ffmpeg', banner: _banner5);
      final installer = _FakeInstaller();
      expect(await resolve(provisioner: installer), isNotEmpty);
      expect(installer.calls, 1);
    });

    test('--no-download fails with the install hint instead of downloading', () async {
      stubProbe('ffmpeg', exitCode: 127);
      final installer = _FakeInstaller();
      await expectLater(
        () => resolve(allowDownload: false, provisioner: installer),
        throwsA(
          isA<CliFailure>().having((e) => e.message, 'message', contains('fluvie ffmpeg install')),
        ),
      );
      expect(installer.calls, 0);
    });

    test('a git-master banner is unparsable and triggers a download', () async {
      stubProbe('ffmpeg', banner: _bannerGitMaster);
      final installer = _FakeInstaller();
      expect(await resolve(provisioner: installer), isNotEmpty);
      expect(installer.calls, 1);
    });
  });
}
