import 'dart:ffi';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:test/test.dart';

final class _VersionRunner implements ProcessRunner {
  final calls = <String>[];
  final versions = <String, String>{};

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    calls.add(executable);
    final version = versions[executable];
    return ProcessRunResult(exitCode: version == null ? 1 : 0, stdout: version ?? '', stderr: '');
  }
}

void main() {
  late Directory directory;
  late FfmpegCache cache;
  late _VersionRunner runner;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fluvie_toolchain_test_');
    cache = FfmpegCache(abi: Abi.linuxX64, environment: {'XDG_CACHE_HOME': directory.path});
    runner = _VersionRunner();
  });
  tearDown(() => directory.delete(recursive: true));

  Future<void> cachedPair() async {
    for (final path in [cache.binaryPath!, cache.probePath!]) {
      await File(path).create(recursive: true);
    }
    runner.versions[cache.binaryPath!] = 'ffmpeg version n8.1.1-9-build';
    runner.versions[cache.probePath!] = 'ffprobe version n8.1.1-9-build';
  }

  test('default uses the complete pinned pair ahead of PATH without downloading', () async {
    await cachedPair();
    final tools = await ensureFfmpegToolchain(
      runner,
      cache: cache,
      environment: {},
      allowDownload: false,
    );
    expect(tools.ffmpegPath, cache.binaryPath);
    expect(tools.ffprobePath, cache.probePath);
    expect(tools.environment, {
      'FLUVIE_FFMPEG': cache.binaryPath,
      'FLUVIE_FFPROBE': cache.probePath,
    });
    expect(runner.calls, isNot(contains('ffmpeg')));
  });

  test('partial managed cache fails offline with a pair warm-up instruction', () async {
    await File(cache.binaryPath!).create(recursive: true);
    await expectLater(
      ensureFfmpegToolchain(runner, cache: cache, environment: {}, allowDownload: false),
      throwsA(
        isA<CliFailure>().having(
          (failure) => failure.message,
          'message',
          contains('ffmpeg install'),
        ),
      ),
    );
  });

  test('explicit binaries override environment and keep exact paths', () async {
    runner.versions['/custom/encoder'] = 'ffmpeg version 7.1';
    runner.versions['/custom/prober'] = 'ffprobe version 7.1';
    final tools = await ensureFfmpegToolchain(
      runner,
      binary: '/custom/encoder',
      probeBinary: '/custom/prober',
      environment: {'FLUVIE_FFMPEG': '/ignored'},
      cache: cache,
      allowDownload: false,
    );
    expect(tools.ffmpegPath, '/custom/encoder');
    expect(tools.ffprobePath, '/custom/prober');
    expect(tools.build, 'custom');
  });

  test('system mode deliberately uses the PATH pair', () async {
    runner.versions['ffmpeg'] = 'ffmpeg version 6.1';
    runner.versions['ffprobe'] = 'ffprobe version 6.1';
    final tools = await ensureFfmpegToolchain(
      runner,
      mode: 'system',
      cache: cache,
      environment: {},
    );
    expect(tools.build, 'system');
    expect(tools.ffprobePath, 'ffprobe');
  });

  test('named encoder derives its sibling probe and never falls back on failure', () async {
    runner.versions['/custom/ffmpeg'] = 'ffmpeg version 8.1';
    await expectLater(
      ensureFfmpegToolchain(runner, binary: '/custom/ffmpeg', cache: cache, environment: {}),
      throwsA(
        isA<CliFailure>().having(
          (failure) => failure.message,
          'message',
          contains('/custom/ffprobe'),
        ),
      ),
    );
    expect(runner.calls, isNot(contains('ffprobe')));
  });

  test('incompatible or unrelated probe banners are rejected', () async {
    runner.versions['ffmpeg'] = 'ffmpeg version 8.1';
    runner.versions['ffprobe'] = 'built with gcc 15.1';
    await expectLater(
      ensureFfmpegToolchain(runner, mode: 'system', environment: {}),
      throwsA(isA<CliFailure>()),
    );
  });
}
