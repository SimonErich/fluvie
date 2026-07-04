import 'dart:io';

/// Runs an external executable with an **argument array** and reports the
/// collected result.
///
/// Pure-Dart sibling of the contract in `fluvie` (the CLI cannot depend on
/// the Flutter package): every process the CLI spawns — the ffmpeg probe,
/// `flutter test`, the encode — goes through this seam so unit tests never
/// touch a real binary. Implementations never involve a shell.
// ignore: one_member_abstracts — the seam is the type: mockable where a bare function isn't.
abstract interface class ProcessRunner {
  /// Executes [executable] with [args] (optionally in [workingDirectory])
  /// and completes with its exit code and collected stdout/stderr.
  ///
  /// [environment] is added on top of the inherited parent environment (it
  /// does not replace it), so the caller can hand the child per-run variables
  /// like a unique progress-file path without clobbering PATH or API keys.
  ///
  /// A non-zero exit is a *result*, not an exception — policy belongs to the
  /// caller.
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  });
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
    Map<String, String>? environment,
  }) async {
    final result = await Process.run(
      executable,
      args,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    return ProcessRunResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }
}
