import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/capture_process.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/managed_harness.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_worker_client.dart';

/// Owns one warm Flutter process and its private request directory.
final class NativeRenderWorker {
  NativeRenderWorker._(this.process, this.mailbox, this.client, this.startupMilliseconds);

  /// Starts the managed adapter without adding files to the consumer project.
  static Future<NativeRenderWorker> start({
    required FileTarget target,
    required FfmpegToolchain toolchain,
    required StringSink err,
    ProcessRunner runner = const IoProcessRunner(),
    bool impeller = false,
    Duration startupTimeout = const Duration(minutes: 5),
    Duration requestTimeout = const Duration(minutes: 5),
  }) async {
    if (startupTimeout <= Duration.zero || requestTimeout <= Duration.zero) {
      throw ArgumentError('Worker startup and request timeouts must be positive.');
    }
    final watch = Stopwatch()..start();
    final staged = await stageManagedHarness(
      projectDir: target.projectDir,
      runner: runner,
      target: target,
      worker: true,
    );
    final mailbox = await Directory.systemTemp.createTemp('fluvie_worker_');
    Process? process;
    try {
      process = await Process.start(
        'flutter',
        captureTestArgs(
          key: target.path,
          sandbox: mailbox,
          impeller: impeller,
          harnessPath: staged.harnessPath,
          packageConfigPath: staged.packageConfigPath,
          extraDefines: {'FLUVIE_WORKER_MAILBOX': mailbox.path},
        ),
        workingDirectory: target.projectDir,
        environment: toolchain.environment,
      );
      final client = RenderWorkerClient(
        mailbox: mailbox,
        processExit: process.exitCode,
        timeout: requestTimeout,
      );
      final worker = NativeRenderWorker._(process, mailbox, client, 0);
      worker._streams.addAll([
        process.stdout.transform(utf8.decoder).listen(err.write),
        process.stderr.transform(utf8.decoder).listen(err.write),
      ]);
      int? exit;
      unawaited(process.exitCode.then((code) => exit = code));
      final ready = File('${mailbox.path}/ready.json');
      while (!ready.existsSync()) {
        if (exit != null) throw CliFailure('Flutter worker failed to start (exit $exit).');
        if (watch.elapsed > startupTimeout) {
          throw CliFailure(
            'Flutter worker startup timed out after ${startupTimeout.inSeconds}s. '
            'Check compiler diagnostics or increase --startup-timeout for a cold or large project.',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      worker.startupMilliseconds = watch.elapsedMilliseconds;
      return worker;
    } on Object {
      if (process != null) await _reapWorker(process);
      await mailbox.delete(recursive: true);
      rethrow;
    }
  }

  /// Owned Flutter test launcher.
  final Process process;

  /// Exclusively owned transport directory.
  final Directory mailbox;

  /// Serial request transport.
  final RenderWorkerClient client;

  /// Startup, including staging and Flutter compilation, separate from requests.
  int startupMilliseconds;
  final _streams = <StreamSubscription<String>>[];
  bool _closed = false;

  /// Stops the worker, reaps the process and removes its transport directory.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await client.stop();
      await process.exitCode.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      await _reapWorker(process);
    } on Object {
      await _reapWorker(process);
      rethrow;
    } finally {
      for (final stream in _streams) {
        await stream.cancel();
      }
      if (mailbox.existsSync()) await mailbox.delete(recursive: true);
    }
  }
}

Future<void> _reapWorker(Process process) async {
  process.kill();
  try {
    await process.exitCode.timeout(const Duration(seconds: 3));
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode.timeout(const Duration(seconds: 3));
  }
}
