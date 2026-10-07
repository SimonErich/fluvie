import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:fluvie/src/rendering/render_cancellation.dart';

/// Runs an argument-array process that can be terminated by a render token.
/// Output is drained concurrently, and cancellation waits for process exit so
/// the owner can safely remove its sandbox before completing.
final class CancellableProcessRunner implements ProcessRunner {
  /// Associates this process runner with one render job.
  const CancellableProcessRunner(this.cancellation);

  /// Cancellation lifetime of the owning job.
  final RenderCancellation cancellation;

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    cancellation.throwIfCancelled();
    final process = await Process.start(executable, args, workingDirectory: workingDirectory);
    var completed = false;
    Timer? killTimer;
    unawaited(
      cancellation.whenCancelled.then((_) {
        if (completed) return;
        process.kill();
        killTimer = Timer(const Duration(milliseconds: 500), () {
          if (!completed) process.kill(ProcessSignal.sigkill);
        });
      }),
    );
    try {
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      final code = await process.exitCode;
      final stdout = await output;
      final stderr = await errors;
      cancellation.throwIfCancelled();
      return ProcessRunResult(exitCode: code, stdout: stdout, stderr: stderr);
    } finally {
      completed = true;
      killTimer?.cancel();
    }
  }
}
