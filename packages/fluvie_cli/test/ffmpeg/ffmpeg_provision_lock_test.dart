import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:test/test.dart';

final class _VersionRunner implements ProcessRunner {
  const _VersionRunner();

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async => const ProcessRunResult(exitCode: 0, stdout: 'fixture version', stderr: '');
}

Future<Process> _holdLock(Directory root, String path) async {
  final script = File('${root.path}/hold_lock.dart');
  await script.writeAsString('''
import 'dart:io';
Future<void> main(List<String> arguments) async {
  final lock = File(arguments.single).openSync(mode: FileMode.append);
  lock.lockSync();
  stdout.writeln('ready');
  await stdin.first;
  lock.closeSync();
}
''');
  final child = await Process.start(Platform.resolvedExecutable, [script.path, path]);
  final ready = child.stdout.transform(utf8.decoder).transform(const LineSplitter()).first;
  unawaited(child.stderr.drain<void>());
  expect(await ready.timeout(const Duration(seconds: 10)), 'ready');
  return child;
}

void main() {
  late Directory root;
  late FfmpegCache cache;
  Process? holder;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fluvie_lock_');
    cache = FfmpegCache(abi: Abi.linuxX64, environment: {'XDG_CACHE_HOME': root.path});
    await Directory(cache.versionDir!).create(recursive: true);
    for (final path in [cache.binaryPath!, cache.probePath!]) {
      await File(path).parent.create(recursive: true);
      await File(path).writeAsString('previous complete pair');
    }
    holder = await _holdLock(root, '${cache.versionDir}.lock');
  });

  tearDown(() async {
    holder?.kill();
    await holder?.exitCode;
    holder = null;
    await root.delete(recursive: true);
  });

  test('reports contention and reuses the pair after the other process releases it', () async {
    final logs = <String>[];
    final installer = FfmpegProvisioner(
      runner: const _VersionRunner(),
      cache: cache,
      lockTimeout: const Duration(seconds: 2),
    );
    final path = await installer.install(
      log: (message) {
        logs.add(message);
        holder!.stdin.writeln('release');
      },
    );
    expect(path, cache.binaryPath);
    expect(logs.single, contains('Waiting'));
    expect(logs.single, contains('${cache.versionDir}.lock'));
    expect(File(path).readAsStringSync(), 'previous complete pair');
    await holder!.exitCode;
  });

  test('bounds contention with a typed recovery error and preserves the pair', () async {
    final installer = FfmpegProvisioner(
      runner: const _VersionRunner(),
      cache: cache,
      lockTimeout: const Duration(milliseconds: 50),
    );
    await expectLater(
      installer.install(),
      throwsA(
        isA<CliFailure>()
            .having((error) => error.code, 'code', 'toolchain_busy')
            .having((error) => error.details['lockPath'], 'lock path', '${cache.versionDir}.lock')
            .having((error) => error.message, 'recovery', contains('--toolchain system')),
      ),
    );
    expect(File(cache.probePath!).readAsStringSync(), 'previous complete pair');
    holder!.stdin.writeln('release');
    await holder!.exitCode;
    expect(await installer.install(), cache.binaryPath);
  });
}
