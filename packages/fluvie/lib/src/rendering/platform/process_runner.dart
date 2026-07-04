import 'dart:io';

import 'package:riverpod/riverpod.dart';

/// Runs an external executable with an **argument array** and reports the
/// collected result.
///
/// This is the mockability seam for everything process-shaped: the FFmpeg
/// provider and the probe service depend on this contract, so their logic is
/// unit-tested without spawning a single real process. Implementations never
/// involve a shell — arguments reach the OS exactly as the array says.
// ignore: one_member_abstracts — new-service seam; mockable (mocktail) where a function isn't.
abstract interface class ProcessRunner {
  /// Executes [executable] with [args] (optionally in [workingDirectory])
  /// and completes with its exit code and collected stdout/stderr.
  ///
  /// A non-zero exit is a *result*, not an exception — policy belongs to the
  /// caller, which knows what the process was for.
  Future<ProcessRunResult> run(String executable, List<String> args, {String? workingDirectory});
}

/// The collected outcome of one finished process run.
final class ProcessRunResult {
  /// Creates a result from the process's [exitCode], [stdout] and [stderr].
  const ProcessRunResult({required this.exitCode, required this.stdout, required this.stderr});

  /// The process exit code (`0` means success).
  final int exitCode;

  /// Everything the process wrote to stdout, decoded as text.
  final String stdout;

  /// Everything the process wrote to stderr, decoded as text.
  final String stderr;
}

/// The real [ProcessRunner]: `dart:io`'s [Process.run] with an argument
/// array, never a shell (`runInShell` stays `false`).
final class IoProcessRunner implements ProcessRunner {
  /// Creates the runner; it is stateless and const.
  const IoProcessRunner();

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final result = await Process.run(executable, args, workingDirectory: workingDirectory);
    return ProcessRunResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }
}

/// The process runner used by every process-touching service; defaults to
/// [IoProcessRunner] and is overridable with a mock in tests.
final processRunnerProvider = Provider<ProcessRunner>((ref) => const IoProcessRunner());
