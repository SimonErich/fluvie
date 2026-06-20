import 'dart:ffi';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';
import 'package:fluvie_cli/src/ffmpeg_command.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRunner extends Mock implements ProcessRunner {}

void _drop(String _) {}

/// Records its arguments and returns a fixed path (or throws).
final class _FakeInstaller implements FfmpegInstaller {
  _FakeInstaller(this.path, {this.error});
  final String path;
  final CliFailure? error;
  bool? forcedWith;

  @override
  Future<String> install({bool force = false, ProvisionLog log = _drop}) async {
    forcedWith = force;
    if (error != null) throw error!;
    log('downloading...');
    return path;
  }
}

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  late Directory tmpRoot;
  late FfmpegCache cache;
  late _MockRunner runner;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    tmpRoot = Directory.systemTemp.createTempSync('fluvie_ffmpeg_cmd_');
    cache = FfmpegCache(abi: Abi.linuxX64, environment: {'XDG_CACHE_HOME': tmpRoot.path});
    runner = _MockRunner();
    out = StringBuffer();
    err = StringBuffer();
  });

  tearDown(() {
    if (tmpRoot.existsSync()) tmpRoot.deleteSync(recursive: true);
  });

  FfmpegCommand command(FfmpegInstaller installer) =>
      FfmpegCommand(runner: runner, cache: cache, installer: installer);

  Future<int> exec(FfmpegInstaller installer, List<String> args) =>
      command(installer).execute(FfmpegCommand.buildParser().parse(args), out: out, err: err);

  group('install', () {
    test('installs and reports the path (no force by default)', () async {
      final installer = _FakeInstaller(cache.binaryPath!);
      final code = await exec(installer, ['install']);

      expect(code, 0, reason: err.toString());
      expect(installer.forcedWith, isFalse);
      expect(out.toString(), contains(cache.binaryPath));
    });

    test('--force forwards force to the installer', () async {
      final installer = _FakeInstaller(cache.binaryPath!);
      await exec(installer, ['install', '--force']);
      expect(installer.forcedWith, isTrue);
    });

    test('a failed install is exit 1 with the failure message', () async {
      final installer = _FakeInstaller(cache.binaryPath!, error: const CliFailure('checksum boom'));
      final code = await exec(installer, ['install']);

      expect(code, 1);
      expect(err.toString(), contains('checksum boom'));
    });
  });

  group('path', () {
    test('prints the managed binary path', () async {
      final code = await exec(_FakeInstaller(cache.binaryPath!), ['path']);
      expect(code, 0);
      expect(out.toString().trim(), cache.binaryPath);
    });

    test('fails when no cache directory resolves', () async {
      final homeless = FfmpegCommand(
        runner: runner,
        cache: FfmpegCache(abi: Abi.linuxX64, environment: const <String, String>{}),
        installer: _FakeInstaller('/x'),
      );
      final code = await homeless.execute(
        FfmpegCommand.buildParser().parse(['path']),
        out: out,
        err: err,
      );
      expect(code, 1);
      expect(err.toString(), contains('cache'));
    });
  });

  group('status', () {
    test('reports the pinned build and "not installed" when absent', () async {
      final code = await exec(_FakeInstaller(cache.binaryPath!), ['status']);
      expect(code, 0);
      expect(out.toString(), contains(pinnedFfmpegBuildLabel));
      expect(out.toString(), contains('not installed'));
    });

    test('reports the version banner when installed', () async {
      File(cache.binaryPath!)
        ..createSync(recursive: true)
        ..writeAsStringSync('stub');
      when(() => runner.run(cache.binaryPath!, const ['-version'])).thenAnswer(
        (_) async => const ProcessRunResult(
          exitCode: 0,
          stdout: 'ffmpeg version 8.1 Copyright (c)\nbuilt with gcc',
          stderr: '',
        ),
      );

      final code = await exec(_FakeInstaller(cache.binaryPath!), ['status']);

      expect(code, 0);
      expect(out.toString(), contains('ffmpeg version 8.1'));
      expect(out.toString(), contains(cache.binaryPath));
    });

    test('reports an unavailable cache when no directory resolves', () async {
      final homeless = FfmpegCommand(
        runner: runner,
        cache: FfmpegCache(abi: Abi.linuxX64, environment: const <String, String>{}),
        installer: _FakeInstaller('/x'),
      );
      final code = await homeless.execute(
        FfmpegCommand.buildParser().parse(['status']),
        out: out,
        err: err,
      );
      expect(code, 0);
      expect(out.toString(), contains('unavailable'));
    });

    test('notes a present-but-silent binary', () async {
      File(cache.binaryPath!)
        ..createSync(recursive: true)
        ..writeAsStringSync('stub');
      when(
        () => runner.run(cache.binaryPath!, const ['-version']),
      ).thenAnswer((_) async => const ProcessRunResult(exitCode: 0, stdout: '', stderr: ''));

      await exec(_FakeInstaller(cache.binaryPath!), ['status']);
      expect(out.toString(), contains('reported no version'));
    });

    test('notes a present-but-unrunnable binary', () async {
      File(cache.binaryPath!)
        ..createSync(recursive: true)
        ..writeAsStringSync('stub');
      when(
        () => runner.run(cache.binaryPath!, const ['-version']),
      ).thenThrow(const ProcessException('ffmpeg', ['-version'], 'denied'));

      await exec(_FakeInstaller(cache.binaryPath!), ['status']);
      expect(out.toString(), contains('failed to run'));
    });
  });

  group('uninstall', () {
    test('removes an installed build', () async {
      File(cache.binaryPath!)
        ..createSync(recursive: true)
        ..writeAsStringSync('stub');

      final code = await exec(_FakeInstaller(cache.binaryPath!), ['uninstall']);

      expect(code, 0);
      expect(File(cache.binaryPath!).existsSync(), isFalse);
      expect(out.toString().toLowerCase(), contains('removed'));
    });

    test('is a no-op when nothing is installed', () async {
      final code = await exec(_FakeInstaller(cache.binaryPath!), ['uninstall']);
      expect(code, 0);
      expect(out.toString().toLowerCase(), contains('nothing'));
    });
  });

  group('usage', () {
    test('no action is a usage error naming the verbs', () async {
      final code = await exec(_FakeInstaller('/x'), const []);
      expect(code, 64);
      expect(err.toString(), contains('install'));
      expect(err.toString(), contains('status'));
    });

    test('an unknown action is a usage error', () async {
      final code = await exec(_FakeInstaller('/x'), ['frobnicate']);
      expect(code, 64);
      expect(err.toString(), contains('frobnicate'));
    });

    test('default wiring constructs (real cache and provisioner)', () {
      expect(FfmpegCommand.new, returnsNormally);
    });
  });
}
